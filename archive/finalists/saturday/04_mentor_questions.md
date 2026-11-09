# Mentor questions

Matthew runs every slot and asks the questions. The lane owner stands beside him for technical (Marco) and faculty (Everett) questions to ask follow-ups. Write answers in `mentor_log.md` straight away.

Mentors are not agency users. Log them as mentor input. Never write "users said" about a mentor, on a slide or anywhere else.

Ask each mentor the top question first. Their time is short; two good answers beat five rushed ones.

## Faculty (evaluation method)
| # | When, who | Question | Informs |
|---|---|---|---|
| F1 | 9:30 to 10:30, Kaiying O'Hare | Our main evidence is "would our top 10 have surfaced programs this agency actually won." It favors repeat funding. Is that a defensible proxy for recall, and what would you add to show its bias? | Backtest design (Everett) |
| F2 | same | With 8 to 38 won programs per agency, what pass bar and uncertainty display is honest: a binomial interval, or plain counts? | Backtest reporting |
| F3 | 2:00 to 4:00, Jo Kwon | Our model labels failed kappa 0.6 when the prompts were tuned on the same 60 items. Is our held-out check sound, and how do we present a failed check as evidence? | Label check (Noah), field notes |
| F4 | 7:00 to 8:00, Weitong Zhang | Read our limits slide and fact sheet as a hostile judge. Which claim breaks first? | Final fixes |

## Technical (Azure)
| # | When, who | Question | Informs |
|---|---|---|---|
| T1 | 9:30 to 10:30, Pratik Patekar or Girish Wangikar | Daily refresh: Container Apps Job or Azure Function? Which is cheaper and easier for a state developer to own? | Daily job (Marco) |
| T2 | same | The JS tool reads `payload.json` from Blob. Managed identity through the container, or a SAS URL? Which is safer to demo? | Blob wiring |
| T3 | same | Cold start is 38 seconds at min replicas 0. Is min 1 during judging the right fix, or is there a cheaper warm-up? | Sunday setup |
| T4 | 2:00 to 4:00, Haihan Gao or Girish Wangikar | For `POST /feedback` with no personal data, is rate limiting plus validation in the app enough, or does Azure need something in front? | Feedback endpoint |
| T5 | same | What deploy artifact would OSBM IT expect from us: Bicep, a script, or the README alone? | README |
| T6 | 7:00 to 8:00, Haihan Gao | Can you rerun the pipeline from the README alone? Where do you get stuck? | README |

## Industry (adoption and pitch)
| # | When, who | Question | Informs |
|---|---|---|---|
| I1 | 11:00 to 12:00, Rhett Lavender | When your organization triages funding or bids, which costs more: chasing a bad lead or missing a good one? How should that set our top-10 cap? | Flag size, pitch |
| I2 | same | What would make a budget director fund a 60-day pilot of this? What proof did your last approved pilot need? | Pilot slide |
| I3 | same | Here is the live tool. Pick an agency and tell us the first thing that confuses you. | UI fixes (Marco) |
| I4 | 2:00 to 4:00, Aries Rosales | Timed task: "Find one grant to act on for DPI or DEQ." Start a timer, say nothing, note every pause and question. | Field notes, UI |
| I5 | same | An LLM reads eligibility and we show its quote. What would make a skeptical buyer trust that, or not? | Notice reader, pitch |
