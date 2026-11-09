# Model vs hand labels (validation)

Model: qwen2.5:14b, prompt evalpool-v3, temperature 0. Hand labels: one labeler (Kent), so this is agreement with one person, not ground truth.

Gate (decision B): recall of hand 'relevant' >= 0.80 and binary kappa >= 0.60. Result: **FAIL**.
Recall is counted when the model says relevant OR maybe on a hand-relevant item; the stricter model-'relevant'-only recall is in agreement.csv. Decision B does not say which; confirm.

```
                                   agency  n hand_relevant hand_rel_or_maybe
1     Department of Environmental Quality 20             0                 3
2 Department of Health and Human Services 20             2                 5
3            Department of Public Schools 20             1                 4
4                                     ALL 60             3                12
  recall_relevant_by_model_relevant recall_relevant_by_model_rel_or_maybe
1                                NA                                    NA
2                                 1                                     1
3                                 1                                     1
4                                 1                                     1
  kappa_binary exact_agreement_3way
1        0.000                0.850
2        0.467                0.800
3        0.571                0.850
4        0.444                0.833

Confusion (rows hand, columns model):
             relevant maybe not relevant
relevant            3     0            0
maybe               0     3            6
not relevant        0     4           44
```

Quotes failing verification (forced to 'not relevant'): 0 of 60.
Counts are tiny (60 items); one item moves recall by several points.
