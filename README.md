# CMDC.jl

**Notice**: The `CMDD.jl` library has been renamed to `CovidCountyData.jl`

Please use that package instead of this one. See the [CovidCountyData.jl package on GitHub](https://github.com/CovidCountyData/CovidCountyData.jl) for more information

This package will remain active for historical users of `CMDC.jl`, but we strongly encourage all users to upgrade to the new package to continue receiving new features and bug fixes.

# Old documentation


Welcome to the Julia client library for accessing the COVID Modeling Data Collaborative (CMDC) database.

Links:

- [Repository](https://github.com/valorumdata/CMDC.jl)
- [Website](https://covid.valorum.ai/)
- [Python](https://github.com/valorumdata/cmdc.py) and [R](https://github.com/valorumdata/cmdcR) clients
- [Raw REST API](https://covid.valorum.ai/rest-api)
- [GraphQL API](https://covid.valorum.ai/graphql-api)

## COVID Modeling Data Collaborative

The COVID Modeling Data Collaborative (CMDC) is a project funded by [Schmidt Futures](https://schmidtfutures.com/) and seeks to simplify the data ingestion process for researchers and policy makers who are working to enact and understand COVID-19 related policies. We accomplish this goal in several ways:

- Collect unique, hard-to-acquire, datasets that are not widely distributed
- Aggregate data collected by other related organizations into a centralized database
- Work with other related organizations to expand and improve their data collection processes
- Build tools, such as this library (and [Python](https://github.com/valorumdata/cmdc.py) and [R](https://github.com/valorumdata/cmdcR) equivalents), to simplify the data ingestion process

More information about our project and what data is collected can be found on our [website](https://covid.valorum.ai/).

We are always looking to hear from both those who would like to help us build CMDC and those who would like use CMDC. [Please reach out to us](https://covid.valorum.ai/contact)!

## Install

Enter package mode (using `]`) and then input `add https://github.com/valorumdata/CMDC.jl`


## Datasets

You can see a list of currently available datasets using:

```
julia> CMDC.datasets()
8-element Array{Symbol,1}:
 :states
 :counties
 :covid_historical
 :covid
 :demographics
 :mobility_locations
 :economics
 :mobility_devices
```

Each dataset has an associated function

You can get detailed information on a specific dataset using `?`. For example

```
help?> demographics
  CMDC endpoint demographics

  Currently, the following variables are collected in the database

    •    Total population

    •    Median age

    •    Fraction of the population over 65

    •    Fraction of the population who identify as various races or as Hispanic/Latino

    •    Fraction of the population with various degrees of education

    •    Fraction of the population that commutes in various ways

    •    Mean travel time to work (minutes)

    •    Median household income

    •    Mean household income

    •    Fraction of the (civilian) population with/without health insurance

    •    Fraction of families who had an income less than poverty level in the last year

  These variables are collected from the 2018 American Community Survey (5 year) in order to ensure that we have data for each county. Please note that we are willing (and easily able!) to add other years or variables if there is interest –- The variables that we
  do include are because people have asked about them.

  Source(s):

  US Census American Community Survey (https://www.census.gov/programs-surveys/acs)

  Available filters are: meta_date, fips, variable, value, select, order, offset and limit

  Set any filter as keyword argument to demographics() function
```

## Requesting Data

Requesting a dataset has three parts:

1. Create a client
2. Build a request with desired datasets
3. `fetch` the datasets

### 1. Create a client

To create a client, use the `Client` function

```
julia> c = Client()
CMDC Client

julia>
```

You can optionally pass in an API key if you have one (see section on API keys below)

```
julia> c = Client(apikey="my api key")
CMDC Client

julia>
```

If you have previously registered for an API key (again, see below) on your current machine, it will be loaded and used automatically for you

In practice you should rarely need to use the `apikey` argument unless you are loading the key from an environment variable or other source

### 2. Build a request

Each of the datasets in the API have an associated function

To add datasets to the current request, you use the `request(::Client, ::dataset...)` function

```
julia> request!(c, covid(state=6))
CMDC Client. Current request:
 - covid
  - state: 6


julia> request!(c, demographics())
CMDC Client. Current request:
 - demographics
 - covid
  - state: 6


julia> c
CMDC Client. Current request:
 - demographics
 - covid
  - state: 6


julia>
```

`request!` will build up a request for the `Client` and will return the `Client` itself.

You can see that the printed form of the `Client` is updated to show you what the current request looks like

To clear the current request, use `reset!(::Client)`:

```
julia> reset!(c); c
CMDC Client

julia>
```

Multiple datasets can be addded in one call to `request!`

```
julia> request!(c, demographics(), covid(fips="<100"))
CMDC Client. Current request:
 - demographics
 - covid
  - fips: <100


julia>
```

#### Filtering data

Each of the dataset functions has a number of filters that can be applied

This allows you to select certain rows and/or columns

For example, in the above example we had `covid(fips="<100")`. This instructs the client to only fetch data for US fips codes less than 100, which would be all US states and territories.

Refer to the help/documentation for each dataset's function for more information on which filters can be passed

Also, check out the `examples.jl` file for more examples

**NOTE:** If a filter is passed to one dataset in the request but is applicable to other datasets in the request, it will be applied to *all* datasets

For example in `request!(c, demographics(), covid(fips="<100"))` we only specifcy a `fips` filter on the `covid` dataset

However, when the data is collected it will also be applied to `demographics`

We do this because we end up doing an inner join on all requested datasets, so when we filter the fips in `covid` they also get filtered in `demographics`

### 3. Fetch the data

Now for the easy part!

When you are ready with your current

To fetch the data, call the `fetch` function on the client:

```
julia> df = fetch(c)
4963×39 DataFrames.DataFrame. Omitted printing of 36 columns
│ Row  │ fips  │ Fraction of population over 65_2018-01-01 │ Mean household income_2018-01-01 │
│      │ Int64 │ Union{Missing, Float64}                   │ Union{Missing, Float64}          │
├──────┼───────┼───────────────────────────────────────────┼──────────────────────────────────┤
│ 1    │ 1     │ 17.0                                      │ 69091.0                          │
│ 2    │ 1     │ 17.0                                      │ 69091.0                          │
│ 3    │ 1     │ 17.0                                      │ 69091.0                          │
│ 4    │ 1     │ 17.0                                      │ 69091.0                          │
│ 5    │ 1     │ 17.0                                      │ 69091.0                          │
│ 6    │ 1     │ 17.0                                      │ 69091.0                          │
│ 7    │ 1     │ 17.0                                      │ 69091.0                          │
⋮
│ 4956 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4957 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4958 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4959 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4960 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4961 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4962 │ 56    │ 16.7                                      │ 81935.0                          │
│ 4963 │ 56    │ 16.7                                      │ 81935.0                          │

julia> names(df)
39-element Array{String,1}:
 "fips"
 "Fraction of population over 65_2018-01-01"
 "Mean household income_2018-01-01"
 "Mean travel time to work (minutes)_2018-01-01"
 "Median age_2018-01-01"
 "Median household income_2018-01-01"
 "Percent Asian_2018-01-01"
 "Percent Hispanic/Latino (any race)_2018-01-01"
 "Percent Native American or Alaska Native_2018-01-01"
 ⋮
 "Total population_2018-01-01"
 "vintage"
 "dt"
 "deaths_total"
 "hospital_beds_in_use_covid_total"
 "icu_beds_in_use_covid_total"
 "negative_tests_total"
 "positive_tests_total"
 "ventilators_in_use_covid_total"

julia>
```

Notice that after each successful request, the client is reset so there are no "built-up" requests:

```
julia> c
CMDC Client

julia>
```

## API keys

Our API is and always will be free for unlimited public use

We have an API key system in place to help us understand the needs of our users

We kindly reqeust that you register for an API key so we can understand how to prioritize future work

In order to do so, you can use the `register` function

```
julia> c = Client()
CMDC Client

julia> ismissing(c.apikey)
true

julia> c = register(c)
Please provide an email address to request a free API key: me@test.com
email = readline(stdin) = "me@test.com"
The API key has been reqeusted and will be used on all future requests unless another key is given when creating a Client.
CMDC Client

julia> ismissing(c.apikey)
false

julia>
```

Notice that the `register` function will prompt you to input an email address AND will return a _new_ instance of `Client`

This new `Client` will have the apikey set

Note that if you prefer, you can pass the email address as the second argument and you will not be prompted:

```
julia> c = register(c, "me@test.com")
The API key has been reqeusted and will be used on all future requests unless another key is given when creating a Client.
CMDC Client

julia> ismissing(c.apikey)
false

julia>
```

After you `register` for an API key, we save the key to a file at `~/.cmdc/apikey`

Each time you instantiate a `Client` and do not explicitly pass an apikey (via keyword argument), we will check this file and extract the key if it exists

Thus, to use the key in future sesions you just need to do `c = Client()` and we'll handle the key for you!

## Final thoughts

Due to the urgency of the COVID-19 crisis and the need for researchers, modelers, and policy makers to have accurate data quickly, this project moves fast!

We have created this library so that as we add new datasets to our backend, they automatically appear here and are accessible via this library

Please check back often and see what has been updated
