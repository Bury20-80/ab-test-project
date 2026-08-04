# Marketing A/B Test Analysis

I analyzed a marketing A/B test to check whether showing an advertisement (`ad`) increased conversion compared with showing a public-service announcement (`psa`). I performed the data-quality checks in SQLite and the statistical analysis in Python. I also used power analysis and Monte Carlo simulation to examine how a future experiment could be designed.

## Project goal

The main question was:

> Does the advertisement improve conversion, and is the observed uplift large enough to support a rollout decision?

The dataset does not include advertising costs, revenue, dates, or experiment-assignment logs. For that reason, the final recommendation is conditional rather than a simple ship/no-ship decision.

## Key results

The dataset contains **588,101 unique users**. I found no duplicate user IDs or missing values in the required columns.

| Metric | Result |
|---|---:|
| Users in the ad group | 564,577 |
| Users in the PSA group | 23,524 |
| Ad conversion rate | 2.55% |
| PSA conversion rate | 1.79% |
| Absolute uplift | **+0.77 percentage points** |
| Relative uplift | **+43.1%** |
| 95% CI for absolute uplift | **+0.59 to +0.94 pp** |
| Two-sided z-test p-value | **1.71 × 10⁻¹³** |
| Scenario MDE | 0.50 pp |
| 80% detectable uplift with the observed allocation | ~0.26 pp |

The ad group had a higher conversion rate than the PSA group. The confidence interval does not include zero, and the observed uplift is larger than the 0.50 percentage-point threshold used in the experiment-design scenario.

![Conversion rates](visuals/conversion_rates.png)

![Effect estimate](visuals/effect_estimate.png)

## Conclusion

Based on the available data, I would continue toward rollout, but only after checking the experiment setup and unit economics.

The statistical result supports the ad variant under the assumption that users were assigned correctly and conversion tracking was consistent between groups. Before making a production decision, I would still verify:

1. the randomization and exposure logic in the experiment logs;
2. the value of an incremental conversion compared with the additional advertising cost;
3. conversion quality and downstream guardrail metrics;
4. whether the effect is stable over time and across important user segments.

## What I did

### 1. Data validation in SQL

I performed the initial checks in SQLite using DBeaver. The SQL scripts cover:

- row counts and unique users;
- duplicate user IDs;
- missing values;
- valid experiment groups and Boolean outcomes;
- ranges for exposure count, weekday, and hour;
- group sizes, conversion counts, and traffic allocation;
- basic exposure statistics by group.

### 2. Experiment-design scenario

I used the observed PSA conversion rate as a baseline proxy for planning a future balanced experiment. The scenario assumes:

- baseline conversion rate: approximately 1.79%;
- absolute MDE: 0.50 percentage points;
- significance level: 0.05;
- target power: 80%;
- allocation: 1:1.

Under these assumptions, the required sample size is approximately **12,474 users per group**. I then performed a Monte Carlo simulation to check whether the analytical power calculation produced a similar result.

The 0.50 pp MDE is a scenario assumption, not a universal business threshold. At the observed baseline, it represents an uplift of roughly 28%. In a real business setting, I would derive this threshold from conversion value, margin, advertising cost, traffic volume, and the cost of delaying a decision.

![Power curve](visuals/power_curve.png)

### 3. Analysis of the observed experiment

Because conversion is a binary outcome, I used a two-proportion z-test to compare the groups. I reported both the absolute and relative uplift, together with a 95% confidence interval for the absolute difference.

I also estimated the smallest uplift that the observed, highly unequal allocation could detect with 80% power. This is more useful than calculating observed power from the effect already present in the data.

### 4. Exposure-frequency analysis

I explored the relationship between the recorded number of ad exposures and conversion within the ad group. Users with more recorded exposures converted more often, but I did not treat this as a causal result.

Exposure frequency was not randomized and may be related to targeting, engagement, time at risk, campaign-delivery rules, or stopping ads after conversion. A causal frequency analysis would require a different experiment, such as random assignment to frequency caps.

![Exposure association](visuals/exposure_conversion_association.png)

## Dataset

The analysis uses the [Marketing A/B Testing dataset](https://www.kaggle.com/datasets/faviovaz/marketing-ab-testing) published on Kaggle.

The main columns are:

| Column | Description |
|---|---|
| `user id` | Unique user identifier |
| `test group` | `ad` or `psa` experiment group |
| `converted` | Whether the user converted |
| `total ads` | Recorded number of exposures |
| `most ads day` | Day with the highest number of exposures |
| `most ads hour` | Hour with the highest number of exposures |

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

I used this notebook to:

- define the experiment-design assumptions;
- calculate the required sample size;
- validate the expected power with Monte Carlo simulation;
- show the relationship between sample size and power;
- describe the risk of repeatedly checking a fixed-horizon experiment.

### `02_real_data_analysis.ipynb`

I used this notebook to:

- load and validate the dataset;
- calculate group-level conversion metrics;
- run the two-proportion z-test;
- estimate the confidence interval for the absolute uplift;
- calculate the detectable MDE for the observed allocation;
- translate the estimated effect into incremental conversions under explicit traffic scenarios;
- produce the main result charts.

### `03_dose_response.ipynb`

I used this notebook to:

- group users by exposure count;
- compare conversion rates across exposure buckets;
- calculate a point-biserial correlation as an association measure;
- explain why the result should not be interpreted causally;
- produce the exposure-association chart.

## Running the project

From the repository root, create a virtual environment:

```bash
python -m venv .venv
```

Activate it:

```bash
# Windows PowerShell
.venv\Scripts\Activate.ps1

# macOS / Linux
source .venv/bin/activate
```

Install the dependencies and start JupyterLab:

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
jupyter lab
```

Run the notebooks in numerical order. The notebooks locate the repository root automatically, so they can be opened from either the root directory or the `notebooks/` directory.

## SQL setup

The SQL scripts use **SQLite syntax** and were run in DBeaver against a local `marketing.db` database.

They assume that:

- the imported table is named `marketing_AB`;
- `converted` is stored as `0`/`1` or an equivalent Boolean text value;
- the original column names with spaces were preserved;
- the installed SQLite version supports window functions.

SQLite does not provide PostgreSQL's `PERCENTILE_CONT`, so I calculated the median exposure count with `ROW_NUMBER()` and `COUNT()` window functions.

## Limitations

- The CSV does not confirm that assignment to `ad` and `psa` was randomized.
- The dataset has no dates, so I could not assess test duration, seasonality, or changes over time.
- Revenue, margin, ad cost, and conversion-quality data are not available.
- The group allocation is highly uneven, with about 96% of users in the ad group.
- The exposure-frequency analysis is observational and uses a post-assignment variable.
- The results may not generalize beyond the users, campaign setup, and time period represented in the dataset.

## Tools

`SQLite` · `DBeaver` · `Python` · `Jupyter` · `pandas` · `NumPy` · `SciPy` · `statsmodels` · `Matplotlib`