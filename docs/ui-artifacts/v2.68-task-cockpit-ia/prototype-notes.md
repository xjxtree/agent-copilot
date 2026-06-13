# V2.68 Prototype Notes

The prototype direction keeps the existing native split-view shell and changes navigation priority:

- The sidebar starts with agent context, then Work surfaces, then diagnostics.
- Work surfaces are row-like controls with icons, names, and concise summaries.
- Detail content starts with a compact section switcher and a short section-specific scope summary.
- Task Cockpit renders even when no skill is selected.
- Skill-specific diagnostics remain available through Overview, Findings, Conflicts, History, and Review.

Fixture screenshot review confirmed the Work surfaces are visible before Adapter/Health cards and Task Cockpit is selected by default.
