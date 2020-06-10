using CMDC


c = Client()


function multiple_dataset_all(c=Client())
    request!(c, demographics(), covid())
    fetch(c)
end


function multiple_dataset_states_only(c=Client())
    request!(c, demographics(), covid(fips="<100"))
    fetch(c)
end


function multiple_dataset_counties_only(c=Client())
    request!(c, demographics(), covid(fips=">1000"))
    fetch(c)
end


function single_dataset_all(c=Client())
    request!(c, mobility_devices())
    fetch(c)
end


function single_dataset_deaths_filter(c=Client())
    request!(c, covid(fips="<100", variable="deaths_total", value=">100"))

    fetch(c)
end


function single_dataset_multiplestatesallcounties(c=Client())
    request!(c, mobility_devices(state=[6, 48]))

    fetch(c)
end


function single_dataset_onestateallcounties(c=Client())
    request!(c, mobility_devices(state=6))
    fetch(c)
end


function single_dataset_variableselect(c=Client())
    request!(
        c, demographics(
            variable=[
                "Total population",
                "Fraction of population over 65",
                "Median age"
            ]
        )
    )

    fetch(c)
end
