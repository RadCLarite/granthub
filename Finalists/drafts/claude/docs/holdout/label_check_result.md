# Held-out label check (model labels, prompt evalpool-v3)

1. 30 blind items, not used to write the prompt; two labelers (Noah, Matthew) labelled alone without seeing model output. Labelers agree on 70% of items (binary kappa between them 0.322).
2. Catch share of hand "relevant" (model relevant or maybe): strict 0 (0 of 1), lenient 0.5 (3 of 6).
3. Kappa, relevant-plus-maybe vs not relevant: strict 0.614, lenient 0.444. Gate (catch 0.80, kappa 0.60): strict FAIL, lenient FAIL.

How the set was made: `src/R/40_label_check.R stage=draw`. Per agency (Justice, Agriculture and Consumer Services, Labor), 5 items with the most plan-goal words in title and summary plus 5 random, from the open pool minus the 60 validate items. The draw never looked at a model label.

Read before quoting: about 30 items, so one item moves the shares by several points; the top-match half favours what keyword overlap finds, so catch share can be overstated; two labelers show consistency, not ground truth. Which combining rule counts (strict or lenient) is Kent's call. Model labels stay out of the 1:00 payload either way.

```
 reading items_scored hand_relevant caught_rel_or_maybe
  strict           22             1                   0
 lenient           30             6                   3
 caught_model_relevant_only catch_share kappa_yes_no gate
                          0         0.0        0.614 FAIL
                          0         0.5        0.444 FAIL
```

Items where the labelers disagree (9), to discuss; save any change as a new file:

```
 item_no                                          agency  label_A      label_B
      10                             Department of Labor relevant not relevant
      15                           Department of Justice relevant not relevant
      21                             Department of Labor    maybe not relevant
      28                             Department of Labor    maybe not relevant
      30 Department of Agriculture and Consumer Services relevant not relevant
       5 Department of Agriculture and Consumer Services    maybe not relevant
       6 Department of Agriculture and Consumer Services relevant        maybe
       8                             Department of Labor    maybe not relevant
       9 Department of Agriculture and Consumer Services relevant not relevant
```
