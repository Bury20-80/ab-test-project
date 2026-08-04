# Marketing A/B Test: Experiment Design and Conversion Analysis

A recruiter-ready analytics project that combines **SQL data validation**, **Python statistical analysis**, **experiment design**, **Monte Carlo simulation**, and **business interpretation**.

## Business question

Does showing an advertisement (`ad`) increase conversion compared with showing a public-service announcement (`psa`)? If so, is the uplift large enough to justify rollout?

## Executive summary

The dataset contains **588,101 unique users** and no missing values in the required fields. The experiment groups are highly imbalanced: 564,577 users received the advertisement and 23,524 received the PSA.

| Metric | Result |
|---|---:|
| Ad conversion rate | 2.55% |
| PSA conversion rate | 1.79% |
| Absolute uplift | **+0.77 percentage points** |
| Relative uplift | **+43.1%** |
| 95% CI for absolute uplift | **+0.59 to +0.94 pp** |
| Two-sided z-test p-value | **1.71 × 10⁻¹³** |
| Scenario planning threshold | 0.50 pp |
| 80% detectable uplift at observed allocation | ~0.26 pp |

The observed uplift is statistically convincing and exceeds the selected 0.50 percentage-point planning threshold. However, the correct business recommendation is a **conditional rollout**, not an unconditional “ship”: the dataset does not contain assignment metadata, dates, revenue, margin, advertising cost, or guardrail metrics.

![Conversion rates](visuals/conversion_rates.png)

![Effect estimate](visuals/effect_estimate.png)

## Decision

**Recommendation: proceed toward rollout only after validating experiment integrity and unit economics.**

The data support `ad` over `psa` under the assumption that assignment was randomized and measurement was reliable. Before a production decision, I would verify:

1. randomization and exposure logic from experiment logs;
2. the value of an incremental conversion versus incremental ad cost;
3. downstream guardrails and conversion quality;
4. stability over time and across important user segments.

## Why this project is analytically credible

- The primary metric is binary, so the main comparison uses a two-proportion z-test.
- The effect is reported in both absolute and relative terms.
- A 95% confidence interval is shown, rather than relying on the p-value alone.
- Statistical significance is separated from practical significance.
- The 0.50 pp MDE is treated as an explicit scenario assumption, not an industry rule.
- The observed design is assessed through MDE sensitivity, avoiding misleading “observed power.”
- The exposure-frequency analysis is explicitly labeled non-causal.
- SQL checks cover duplicates, missing values, domains, ranges, group allocation, and outcome counts.

## Experiment-design scenario

Notebook 01 asks how a **future balanced experiment** could be planned using the observed PSA conversion rate as a baseline proxy. With:

- control conversion rate: ~1.79%;
- absolute MDE: 0.50 pp;
- two-sided alpha: 0.05;
- target power: 80%;
- 1:1 allocation;

approximately **12,474 users per group** are required. Monte Carlo simulation independently validates the analytical calculation.

The 0.50 pp threshold implies roughly a **28% relative uplift** at this baseline. It should therefore be replaced by an economics-based threshold when revenue and cost data are available.

![Power curve](visuals/power_curve.png)

## Exploratory exposure analysis

Within the `ad` group, conversion is positively associated with the recorded number of ad exposures. This is **not causal evidence**: exposure frequency was not randomized and may reflect targeting, engagement, time at risk, delivery rules, or conversion-related stopping.

![Exposure association](visuals/exposure_conversion_association.png)

## Repository structure

```text
ab_test_project/
├── data/
│   └── raw/
│       └── marketing_AB.csv
├── notebooks/
│   ├── 01_monte_carlo_design.ipynb
│   ├── 02_real_data_analysis.ipynb
│   └── 03_dose_response.ipynb
├── sql/
│   ├── aggregate_groups.sql
│   └── validation.sql
├── visuals/
│   ├── conversion_rates.png
│   ├── effect_estimate.png
│   ├── exposure_conversion_association.png
│   └── power_curve.png
├── README.md
└── requirements.txt
```

## Notebook guide

### `01_monte_carlo_design.ipynb`

- defines alpha, power, and a scenario MDE;
- estimates the required balanced sample size;
- validates power with an efficient binomial Monte Carlo simulation;
- explains fixed-horizon testing and peeking risk;
- saves the power curve.

### `02_real_data_analysis.ipynb`

- validates the dataset and boolean encoding;
- calculates group-level conversion metrics;
- runs the primary two-proportion test;
- estimates a Newcombe confidence interval for the absolute uplift;
- performs MDE sensitivity analysis at the observed allocation;
- translates the effect into incremental conversions under explicit traffic scenarios;
- gives a conditional business recommendation;
- saves the primary result charts.

### `03_dose_response.ipynb`

- explores exposure buckets within the ad group;
- reports point-biserial correlation as an association measure;
- documents targeting, reverse-causality, and post-treatment-bias risks;
- saves the exposure-association chart.

## Reproducing the analysis

From the repository root:

```bash
python -m venv .venv
```

Activate the environment:

```bash
# Windows PowerShell
.venv\Scripts\Activate.ps1

# macOS / Linux
source .venv/bin/activate
```

Install dependencies and start JupyterLab:

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
jupyter lab
```

Run the notebooks in numerical order. They locate the repository root automatically, so they work whether JupyterLab starts in the root directory or in `notebooks/`.

## SQL assumptions

The SQL files use **SQLite syntax** and are intended to be run in DBeaver against the local `marketing.db` database. They assume:

- the imported table is named `marketing_AB`;
- `converted` is stored as a SQLite Boolean-like value (`0`/`1`) or equivalent text such as `True`/`False`;
- source column names with spaces were preserved and therefore require double quotes;
- the SQLite version supports window functions, which are used to calculate the median exposure count without PostgreSQL's `PERCENTILE_CONT`.

## Limitations

- The file does not prove that assignment was randomized.
- There are no dates, so duration, seasonality, and time trends cannot be assessed.
- There is no revenue, margin, ad cost, or conversion-quality information.
- The group allocation is highly uneven.
- The exposure-frequency analysis is observational and uses a post-assignment variable.
- Results may not generalize beyond the represented users, campaign setup, and time window.

## Skills demonstrated

`SQL` · `Python` · `pandas` · `statsmodels` · `SciPy` · `data validation` · `A/B testing` · `power analysis` · `Monte Carlo simulation` · `confidence intervals` · `business communication` · `causal-inference awareness`
