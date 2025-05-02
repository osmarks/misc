import polars as pl
import numpy as np
import json
import matplotlib.pyplot as plt
import math
df = pl.read_csv("counts.csv", schema={"number": pl.String, "count": pl.Int64})

def compute_zipflike(df, k):
    topk = df.top_k(k, by=df["count"])
    frequencies = topk[:, 1].to_numpy()
    ranks = np.arange(len(frequencies)) + 1

    log_frequencies = np.log(frequencies)
    log_ranks = np.log(ranks)

    # https://numpy.org/doc/stable/reference/generated/numpy.linalg.lstsq.html
    A = np.vstack([log_ranks, np.ones(len(log_ranks))]).T
    gradient, y_intercept = np.linalg.lstsq(A, log_frequencies)[0]

    predicted_log_frequencies = log_ranks * gradient + y_intercept

    predicted_log_frequencies_zipf_gradient = log_ranks * -1.0
    rms_y_intercept_zipf = np.sqrt(np.mean((predicted_log_frequencies_zipf_gradient - log_frequencies) ** 2))
    predicted_log_frequencies_zipf_gradient = log_ranks * -1.0 + rms_y_intercept_zipf

    plt.title(f"Top {k} numbers")
    plt.xlabel("log(rank)")
    plt.ylabel("log(frequency)")
    plt.scatter(log_ranks, log_frequencies, label="empirical", color="blue")
    plt.plot(log_ranks, predicted_log_frequencies, label=f"lstsq fit gradient={gradient:.2f}", color="lime")
    plt.plot(log_ranks, predicted_log_frequencies_zipf_gradient, label=f"lstsq fit zipf", color="red")
    plt.legend()
    plt.tight_layout()
    plt.savefig(f"top_{k}_numbers.png")
    #plt.show()
    plt.close()

def compact_cat(x):
    st, en = json.loads(x.replace("(", "["))
    return f"{st:.0e}-{en:.0e}"

def strings_to_numbers(df):
    is_percent = df[:, 0].str.ends_with("%")
    stripped = df[:, 0].str.strip_suffix("%")
    scale = pl.when(is_percent).then(0.01).otherwise(1)
    numbers = stripped.cast(pl.Float64, strict=False)
    return df.with_columns(numbers * scale, df[:, 1])

def frequency_plot_for(values, counts, name, xs, scale="log", ticks=None, axline=None, xlim=None):
    plt.title("Number frequencies")
    ys = [ counts[values == x].sum() for x in xs ]
    plt.plot(xs, ys)
    plt.ylabel("count")
    plt.xlabel("number")
    plt.yscale(scale)
    if ticks:
        plt.xticks(ticks, minor=True)
    if axline:
        plt.axvline(axline, color="red")
    if xlim:
        plt.xlim(xlim)
    plt.savefig(f"{name}_frequency.png")
    plt.close()

with pl.Config() as cfg:
    cfg.set_tbl_formatting("ASCII_MARKDOWN")
    cfg.set_tbl_rows(100)
    cfg.set_tbl_hide_column_data_types(True)

    print("len")
    print(len(df))

    print("total count")
    total_count = df[:, 1].sum()
    print(total_count)

    print("top 30")
    print(df.top_k(30, by=df["count"]))

    print("frequency/rank")
    compute_zipflike(df, 1_000)
    compute_zipflike(df, 10_000)
    compute_zipflike(df, 100_000)

    print("histogram")
    cats, counts = df[:, 1].hist(bins=np.geomspace(1, max(df[:, 1]), num=20), include_category=True, include_breakpoint=False)
    fig, ax = plt.subplots()
    plt.title("Frequency of number frequencies")
    ax.set_yscale("log")
    plt.xticks(rotation=45, ha="right")
    ax.bar([ compact_cat(x) for x in cats ], counts.to_numpy())
    #plt.show()
    fig.subplots_adjust(bottom=0.2)
    plt.savefig("number_freq_freq.png")
    plt.close()

    print("benford")
    real_counts = {}
    real_counts_frac = {}
    benford_frequencies = {}
    for first_digit in range(1, 10):
        first_digit_s = str(first_digit)
        bcount = df.filter(df[:, 0].str.starts_with(first_digit_s))[:, 1].sum()
        bcount_frac = df.filter(df[:, 0].str.starts_with(first_digit_s) & (df[:, 0].str.contains(".", literal=True)))[:, 1].sum()
        print(bcount, bcount_frac)
        real_counts[first_digit_s] = bcount
        real_counts_frac[first_digit_s] = bcount_frac
        benford_frequencies[first_digit_s] = math.log10(first_digit + 1) - math.log10(first_digit)
    total_dcount = sum(real_counts.values())
    total_dfcount = sum(real_counts_frac.values())
    for k in real_counts:
        real_counts[k] /= total_dcount
        real_counts_frac[k] /= total_dfcount
    print(real_counts, real_counts_frac)
    plt.plot(list(real_counts.keys()), list(real_counts.values()), label="Empirical")
    plt.plot(list(real_counts_frac.keys()), list(real_counts_frac.values()), label="Empirical (noninteger)")
    plt.plot(list(benford_frequencies.keys()), list(benford_frequencies.values()), label="Benford")
    plt.xlabel("First digit")
    plt.ylabel("Frequency (relative)")
    plt.legend()
    plt.savefig("benford.png")
    plt.close()

    print("to float domain")
    numbers = strings_to_numbers(df)
    numbers_n = numbers[:, 0].to_numpy()
    numbers_c = numbers[:, 1].to_numpy()

    print("median number")
    perm = np.argsort(numbers_n)
    ccounts = numbers_c[perm].cumsum()
    midpoint = total_count // 2
    midpoint_index = np.searchsorted(ccounts, midpoint)
    print(numbers_n[perm[midpoint_index]])

    log_numbers = np.log(np.abs(numbers_n))
    log_numbers = log_numbers[np.isfinite(log_numbers)]

    print("number size histogram")
    counts, bins = np.histogram(log_numbers, bins=256)
    plt.title("Number sizes histogram")
    plt.stairs(counts, bins)
    plt.yscale("log")
    plt.axvline(0)
    plt.ylabel("density")
    plt.xlabel("log(number)")
    plt.savefig("number_size_histogram.png")
    plt.close()

    frequency_plot_for(numbers_n, numbers_c, "small_numbers", np.arange(100), ticks=[ n for n in range(0, 100, 10) ] + [ 2**n for n in range(0, 7) ])
    frequency_plot_for(numbers_n, numbers_c, "years", np.arange(1900, 2100), scale="linear", axline=2020, ticks=[ n for n in range(1900, 2100, 10) ], xlim=0)
