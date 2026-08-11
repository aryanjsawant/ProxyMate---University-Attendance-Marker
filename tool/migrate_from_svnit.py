"""Convert a ProxyMate `svnit`-branch backup into a `master`-branch one.

    python tool/migrate_from_svnit.py backup.json out.json

The two branches use different schemas:

  svnit (v1)   Course -> Component(theory|lab) -> Slot(periodIndex, spanPeriods,
               units, isTutorial, batch), plus a Period table.
  master (v2)  Subject -> Slot(weekday, optional startMin/endMin). No periods,
               no components, no elective groups, no batches.

Three things this has to get right:

1.  **Only your enrolled half of each elective pair survives.** The svnit
    timetable carries both sides of B/C/D/E and filters at read time; master
    has no such concept, so the unenrolled courses are dropped outright.

2.  **Tutorials stay with their theory.** They were already the same component
    on svnit (`isTutorial` was a display flag, not a separate line), so this is
    just a matter of not inventing a split that never existed.

3.  **One class is one attendance.** svnit counted a two-period lab as 2 units.
    master counts every timetable entry as exactly 1, so every record is
    rewritten to `units: 1`. This *changes the percentages* — a lab absence
    used to cost double — which is the intended correction, not a side effect.
"""

import json
import sys
from collections import defaultdict

# master's palette, so imported subjects look native.
PALETTE = [
    0xFF6366F1, 0xFF10B981, 0xFFF59E0B, 0xFFF43F5E, 0xFF0EA5E9,
    0xFF8B5CF6, 0xFFF97316, 0xFF14B8A6, 0xFFEC4899, 0xFF64748B,
]


def convert(src: dict) -> tuple[dict, list[str]]:
    notes: list[str] = []

    enrolled = set(src.get("enrolledCourseIds", []))
    batch = src.get("selectedBatch")
    periods = {p["index"]: p for p in src["periods"]}
    courses = {c["id"]: c for c in src["courses"]}
    comps = {c["id"]: c for c in src["components"]}

    # --- subjects: one per enrolled component ------------------------------
    keep_comps = [
        c for c in src["components"] if c["courseId"] in enrolled
    ]
    subjects = []
    comp_to_subject: dict[str, str] = {}
    for i, c in enumerate(keep_comps):
        course = courses[c["courseId"]]
        name = course["shortName"]
        if c["kind"] == "lab":
            name = f"{name} Lab"
        sid = c["id"]  # reuse the component id; records already point at it
        comp_to_subject[c["id"]] = sid
        subject = {
            "id": sid,
            "name": name,
            "color": PALETTE[i % len(PALETTE)],
            "targetPercent": c.get("targetPercent", 0.75),
        }
        if course.get("faculty"):
            subject["faculty"] = course["faculty"]
        if course.get("venue"):
            subject["room"] = course["venue"]
        subjects.append(subject)

    dropped = sorted(
        courses[cid]["shortName"] for cid in courses if cid not in enrolled
    )
    if dropped:
        notes.append(f"Dropped {len(dropped)} unenrolled courses: {', '.join(dropped)}")

    # --- slots: period index -> wall-clock times ---------------------------
    slots = []
    for s in src["slots"]:
        comp = comps[s["componentId"]]
        if comp["courseId"] not in enrolled:
            continue
        # Batch-split slots only apply to the batch the student is in.
        if s.get("batch") and s["batch"] != batch:
            continue

        span = s.get("spanPeriods", 1)
        start = periods.get(s["periodIndex"])
        end = periods.get(s["periodIndex"] + span - 1)
        if start is None or end is None:
            notes.append(f"Skipped slot {s['id']}: references a missing period")
            continue

        slots.append(
            {
                "id": s["id"],
                "subjectId": comp_to_subject[s["componentId"]],
                "weekday": s["weekday"],
                "startMin": start["startMin"],
                "endMin": end["endMin"],
                **({"room": s["room"]} if s.get("room") else {}),
            }
        )

    # --- records: same history, but one class counts once ------------------
    records = []
    rewritten = 0
    orphaned = 0
    for r in src["records"]:
        sid = comp_to_subject.get(r["componentId"])
        if sid is None:
            orphaned += 1
            continue
        if r.get("units", 1) != 1:
            rewritten += 1
        rec = {
            "id": r["id"],
            "subjectId": sid,
            "date": r["date"],
            "status": r["status"],
            "units": 1,
            "isManual": r.get("isManual", False),
        }
        if r.get("slotId"):
            rec["slotId"] = r["slotId"]
        if r.get("note"):
            rec["note"] = r["note"]
        records.append(rec)

    if rewritten:
        notes.append(f"Reset {rewritten} multi-unit records to count as 1 class")
    if orphaned:
        notes.append(f"Dropped {orphaned} records belonging to unenrolled courses")

    old_settings = src.get("settings", {})
    out = {
        "schemaVersion": 2,
        "exportedAt": src.get("exportedAt"),
        "term": src["term"],
        "subjects": subjects,
        "slots": slots,
        "records": records,
        "settings": {
            "nudgeOffsetMinutes": old_settings.get("nudgeOffsetMinutes", 30),
            "dayEndsAtMinutes": 18 * 60,
            "nudgeEnabled": old_settings.get("nudgeEnabled", True),
            "weeklySummaryEnabled": old_settings.get("weeklySummaryEnabled", True),
            "hasSeenWalkthrough": True,
        },
    }
    if src.get("lastGeneratedDate"):
        out["lastGeneratedDate"] = src["lastGeneratedDate"]
    return out, notes


def summarise(src: dict, out: dict) -> None:
    """Print attendance before and after, so the maths can be eyeballed."""
    comps = {c["id"]: c for c in src["components"]}
    courses = {c["id"]: c for c in src["courses"]}
    names = {s["id"]: s["name"] for s in out["subjects"]}

    def tally(records, key, unit_key):
        agg = defaultdict(lambda: [0, 0])  # attended, held
        for r in records:
            u = r[unit_key] if unit_key else 1
            if r["status"] in ("present", "absent"):
                agg[r[key]][1] += u
                if r["status"] == "present":
                    agg[r[key]][0] += u
        return agg

    before = tally(src["records"], "componentId", "units")
    after = tally(out["records"], "subjectId", "units")

    print(f"\n{'subject':<18}{'before':>12}{'after':>12}   change")
    print("-" * 56)
    for cid in sorted(after, key=lambda c: names.get(c, c)):
        ba, bh = before.get(cid, [0, 0])
        aa, ah = after[cid]
        bp = f"{ba}/{bh} {ba / bh * 100:.0f}%" if bh else "—"
        ap = f"{aa}/{ah} {aa / ah * 100:.0f}%" if ah else "—"
        mark = "" if (ba, bh) == (aa, ah) else "  <-- lab units fixed"
        print(f"{names.get(cid, cid):<18}{bp:>12}{ap:>12}{mark}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src = json.load(open(sys.argv[1], encoding="utf-8"))
    if src.get("schemaVersion") != 1:
        sys.exit(f"Expected a schemaVersion 1 backup, got {src.get('schemaVersion')}")

    out, notes = convert(src)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)

    print(f"Wrote {sys.argv[2]}")
    print(f"  {len(out['subjects'])} subjects, {len(out['slots'])} timetable "
          f"entries, {len(out['records'])} records")
    for n in notes:
        print(f"  - {n}")
    summarise(src, out)
