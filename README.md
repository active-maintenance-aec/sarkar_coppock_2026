# Active Maintenance Report: sarkar_coppock_2026


- [Summary](#summary)
- [What was run](#what-was-run)
- [Checks and what they do not
  cover](#checks-and-what-they-do-not-cover)
- [Recorded and not filed](#recorded-and-not-filed)
- [Not done](#not-done)

**Archived at Zenodo:** [doi:10.5281/zenodo.24168417](https://doi.org/10.5281/zenodo.24168417). This DOI always resolves to the latest release of the maintained version.

## Summary

The deposit is Harvard Dataverse file 13506181
(`doi:10.7910/DVN/NHDFFS`). `errata.qmd` lists 15 entries in the
article’s text, labels, and one metadata sheet. None changes a
conclusion. This repository has no independent rewrite, which falls
short of Stage 3: every computed value comes from a rerun of the
deposit’s own code.

## What was run

A stripped rerun (`maintained/run_archive.R`) ran 109 scripts, and 109
exit 0. It reproduces all 278 shipped `estimates/` files, with a largest
difference in `estimate` or `std.error` of 7^{-15}. Of 56 output tables,
49 match the shipped text. Six differ only in a rule width. The seventh,
`selection_model.tex` (Table H.51), differs in value. Its script sets no
seed, so a bootstrap is the likely cause, which I did not establish.
Lambda1’s intervals include 1 for all three estimands in the rerun, so
the appendix’s verdict holds on this run.

The deposit omits Wallsten and Nteta’s raw data and its cleaning script
is entirely commented out, so that study’s shipped cleaned file is an
input the rerun cannot test.

## Checks and what they do not cover

- **Prose values.** 51 extracted values are compared at the page’s
  precision, and 11 disagree, each reported by the spine. These compare
  the page with the deposit’s own pipeline, so a defect in cleaning that
  both inherit would pass.
- **Tables.** 294 of 294 appendix table rows and Table 4 cells appear on
  the page. A row is matched as a run of numbers anywhere in the
  appendix, so this does not show it sits in the right table, and Table
  4’s cells are matched by membership on their page. Appendix Tables A
  and H.48 to H.51 are not in this gate.
- **Outcome ranges.** `maintained/outcome_ranges.R` wraps `lm_robust`
  and records each regression’s outcome. All 34 outcomes span at most
  one scale length, as the article says, three of them reversed to run
  from -1 to 0. The trace covers `code/analysis/`, not
  `code/analysis_s/`.
- **Polarity.** Read in the cleaning scripts for Rahmani et al., Masoud
  et al., and Nyonzo et al.: each message’s outcome is coded so higher
  means its intended direction, as the article says. The other studies
  were not read for polarity.
- **Negative controls.** 8 of 8 control runs behave as required. These
  test that the gates fire on those faults only.
- **Page checks.** Quotes in the spine were read on rendered crops.
  Those of entries 2 to 5 in the sentence-long form rest on crops of
  their key clause and the page’s text. The spelling Slothuus rests on a
  Crossref family-name match, without confirming the manuscript itself.

## Recorded and not filed

- “mouthers” in Section C.1 may be the original study’s text, and nobody
  has checked it.
- The appendix’s “Sperber … (2024)”, and the introduction’s citation of
  Sperber, McClendon, and Kaaba (2022) for null findings on political
  engagement where Table F.47 gives that paper a 7.2-point difference,
  were not read on the page.
- Section F’s rule for “inconsistent” does not cover Condra et al.’s
  large positive effect, coded Inconsistent, and Siegel and Badaan’s row
  says the findings “contrast” with the meta-analysis while coded
  Consistent. These are judgments in a table the authors own.
- “Demora et al.” on Figures 8 to 10 against “DeMora” elsewhere was not
  read on a crop, and the page’s “DeMora et al. 2021” (p. 4) against
  2024 was seen and not resolved.

## Not done

The 31 and 32 estimands of the narrative reviews, the introduction’s
CATE statements, Tables 1 to 3 against the manifest, and appendix
Section B’s prose were not compared with anything. A clean end-to-end
run of `run_all.R` has not been made, and a fresh fetch of the deposit
was not exercised. `maintained/findings_draft.md` is the superseded
working draft, kept because it holds the unfiled candidates’ first
measurements.
