# test_metrics.R -- hand-computed FAKE data (ids "x1".. are made up; nothing real).
here <- dirname(normalizePath(sub("^--file=", "", commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))][1])))
source(file.path(here, "score_labels.R"))
n_pass <- 0L; n_all <- 0L
check <- function(name, got, want, tol = 1e-9) {
  n_all <<- n_all + 1L
  ok <- if (is.na(want)) is.na(got) else (!is.na(got) && abs(got - want) < tol)
  if (ok) n_pass <<- n_pass + 1L else cat("FAIL:", name, "got", got, "want", want, "\n")
}
raises <- function(expr) inherits(try(expr, silent = TRUE), "try-error")

ids <- paste0("x", 1:12)
v <- setNames(c(TRUE,FALSE,TRUE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,TRUE,TRUE), ids)   # 4 positives
check("precision@10", precision_at_k(ids, v, 10)$value, 0.2)
check("precision@3", precision_at_k(ids, v, 3)$value, 2/3)
check("recall@5", recall_at_n(ids, v, 5)$value, 0.5)
check("recall@12", recall_at_n(ids, v, 12)$value, 1)
v2 <- v; v2[c("x2","x4")] <- NA
p <- precision_at_k(ids, v2, 4); check("precision with missing", p$value, 1); check("unlabeled count", p$n_unlabeled, 2)
check("precision all NA", precision_at_k(ids, setNames(rep(NA, 12), ids), 10)$value, NA)
check("recall no positives", recall_at_n(ids, setNames(rep(FALSE, 12), ids), 10)$value, NA)
check("precision empty ranking", precision_at_k(character(0), v, 10)$value, NA)
check("recall empty ranking", recall_at_n(character(0), v, 25)$value, 0)
check("tie order", as.numeric(identical(order_ids(c("b","a","c","d"), c(1,1,1,2)), c("a","b","c","d"))), 1)
check("tie at cut", precision_at_k(order_ids(c("b","a","c","d"), c(1,1,1,2)), c(a=FALSE,b=FALSE,c=TRUE,d=FALSE), 2)$value, 0)

# kappa, hand computed (3 labels): po .8, pe .5 -> .6
a <- c(rep("yes",5), rep("no",5)); b <- c(rep("yes",4), "no", "yes", rep("no",4))
ag <- agreement(a, b); check("pct agreement", ag$pct, 0.8); check("kappa", ag$kappa, 0.6)
check("kappa undefined", agreement(rep("relevant",4), rep("relevant",4))$kappa, NA)
check("agreement drops NA", agreement(c("relevant","not relevant","relevant",NA), c("relevant","not relevant",NA,"maybe"))$n, 2)
check("kappa zero", agreement(c("yes","yes","no","no"), c("yes","no","yes","no"))$kappa, 0)

# two readings x two rules
A <- c("relevant","relevant","not relevant","maybe",NA, "maybe"); B <- c("relevant","not relevant","not relevant","relevant","relevant","maybe")
check("strict relevant-only", sum(combine_verdict(A, B, "relevant", "strict"), na.rm = TRUE), 1)
check("lenient relevant-only", sum(combine_verdict(A, B, "relevant", "lenient"), na.rm = TRUE), 3)
check("strict with maybe", sum(combine_verdict(A, B, c("relevant","maybe"), "strict"), na.rm = TRUE), 3)
check("lenient with maybe", sum(combine_verdict(A, B, c("relevant","maybe"), "lenient"), na.rm = TRUE), 4)
check("blank stays NA", as.numeric(is.na(combine_verdict(A, B, "relevant", "lenient")[5])), 1)

# THE N TRAP: pool of 20 ranked inside itself; N = 20 gives recall 1 no matter what.
pool_ids <- paste0("p", 1:20); pv <- setNames(rep(c(TRUE, FALSE), 10), pool_ids)
check("trap: recall inside pool at N=20 is 1", recall_at_n(rev(pool_ids), pv, 20)$value, 1)
check("trap refused: universe = pool", as.numeric(raises(check_n_valid(20, 20, 20))), 1)
check("trap refused: universe only 30", as.numeric(raises(check_n_valid(20, 30, 20))), 1)
check("N unset refused", as.numeric(raises(check_n_valid(NA, 1500, 20))), 1)
check("N >= universe refused", as.numeric(raises(check_n_valid(1500, 1500, 20))), 1)
check("N=20 on full list warns", as.numeric(identical(suppressWarnings(check_n_valid(20, 1500, 20)), "warn")), 1)
check("N=10 on full list ok", as.numeric(identical(check_n_valid(10, 1500, 20), "ok")), 1)
# Same pool, full list of 100: positives scattered; recall at 20 is NOT trivially 1
full <- c(rbind(paste0("p", 1:20), paste0("o", 1:20)), paste0("o", 21:80))   # p1,o1,p2,o2,...
check("full list recall@20 = 10/10 only for first 10 pool items", recall_at_n(full, pv, 20)$value, 5/10)

# threshold helper: 5 positives in top N, target .7 -> need k = 4 ; scores below
sc <- c(a=9, b=8, c=7, d=6, e=5, f=4, g=3); vv <- c(a=TRUE, b=FALSE, c=TRUE, d=TRUE, e=FALSE, f=TRUE, g=TRUE)  # positives a,c,d,f,g (5)
t1 <- threshold_for_recall(sc, vv, 7, 0.70); check("threshold k", t1$k, 4); check("threshold value", t1$threshold, 4)
t2 <- threshold_for_recall(sc, vv, 4, 0.70); check("threshold unreachable at small N", as.numeric(t2$reachable), 0)   # only a,c,d in top 4
check("threshold none positive", threshold_for_recall(sc, setNames(rep(FALSE,7), names(sc)), 7)$threshold, NA)

cat(n_pass, "of", n_all, "tests pass\n")
if (n_pass != n_all) quit(status = 1)
