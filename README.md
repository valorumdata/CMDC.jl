# CMDC.jl

Julia client library for accessing CMDC API

Example:

```julia
c = Client()
request!(c, covid(), demographics(state=6), mobility_devices())
df = fetch(c)
```
