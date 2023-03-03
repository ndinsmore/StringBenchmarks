module StringBenchmarks

include(joinpath(dirname(@__FILE__), "..", "src/utils", "RandUtils.jl"))
using .RandUtils
using BenchmarkTools

BenchmarkTools.DEFAULT_PARAMETERS.seconds = 1.0
BenchmarkTools.DEFAULT_PARAMETERS.samples = 10000
BenchmarkTools.DEFAULT_PARAMETERS.time_tolerance = 0.15
BenchmarkTools.DEFAULT_PARAMETERS.memory_tolerance = 0.01

const PARAMS_PATH = joinpath(dirname(@__FILE__), "..", "etc", "params.json")
const BASE_DUMP_PATH = joinpath(dirname(@__FILE__), "..", "etc", "juliav1.9.0-beta4.jl_dump")


const SUITE = BenchmarkGroup()

# By using the same length seed these function
function random_length_nonascii_strings(length_range; length_seed = RandUtils.StableRNG(0),
                                       location_seed = RandUtils.StableRNG(1),
                                       total_characters = 1_000_000)
    num_strings = round(total_characters / ((first(length_range) + last(length_range)) / 2))
    fill_char = 's'
    nonascii_char = 'λ'
    function make_rand_string()
        l = rand(length_seed, length_range)
        loc = rand(location_seed, 1:(l - 1))
        return fill_char^(loc - 1) * nonascii_char * fill_char^(l - loc - 1)
    end
    return [make_rand_string() for n in 1:num_strings]
end

function random_length_ascii_strings(length_range; length_seed = RandUtils.StableRNG(0),
                                     total_characters = 1_000_000)
    num_strings = round(total_characters / ((first(length_range) + last(length_range)) / 2))
    fill_char = 's'
    function make_rand_string()
        l = rand(length_seed, length_range)
        return fill_char^l
    end
    return [make_rand_string() for n in 1:num_strings]
end

function isascii_benchmarker(strings)
    ret = true
    for s in strings
        ret &= isascii(s)
    end
    return ret
end

g = addgroup!(SUITE, "isascii")
h = addgroup!(g, "ASCII")
length_ranges = [2:64, 64:512, 512:4096, 4096:32768]
for len in length_ranges
    h["length $len"] = @benchmarkable isascii_benchmarker(strings) setup = (strings = random_length_ascii_strings($len))
end
h = addgroup!(g, "single nonASCII")
for len in length_ranges
    h["length $len"] = @benchmarkable isascii_benchmarker(strings) setup = (strings = random_length_nonascii_strings($len))
end

function length_benchmarker(strings)
    ret = Int(0)
    for s in strings
        ret += length(s)
    end
    return ret
end

g = addgroup!(SUITE, "length")
h = addgroup!(g, "ASCII")
length_ranges = [2:64, 64:512, 512:4096, 4096:32768]
for len in length_ranges
    h["length $len"] = @benchmarkable length_benchmarker(strings) setup = (strings = random_length_ascii_strings($len))
end

h = addgroup!(g, "single nonASCII")
for len in length_ranges
    h["length $len"] = @benchmarkable length_benchmarker(strings) setup = (strings = random_length_nonascii_strings($len))
end

g["julia lines"] = @benchmarkable length_benchmarker(strings) setup = (strings = readlines($BASE_DUMP_PATH))

n = 1_000
ascii_string  = RandUtils.randstring(StableRNG(1), n)
unicode_string  = RandUtils.randstring(StableRNG(1),Char, n)
malformed_string  = String(rand(StableRNG(1),UInt8, n))

function thisind_benchmarker(s)
    l = ncodeunits(s)
    ret = 0
    i=l
    while i >1
        i = thisind(s,i)-1
    end
    return i
end

g = addgroup!(SUITE, "thisind")
g["ascii"] = @benchmarkable thisind_benchmarker($ascii_string)
g["unicode"] = @benchmarkable thisind_benchmarker($unicode_string)
g["malformed"] = @benchmarkable thisind_benchmarker($malformed_string)

function nextind_benchmarker(s)
    l = ncodeunits(s)
    ret = 0
    i=1
    while i < l
        i = nextind(s,i)
    end
    return i
end

g = addgroup!(SUITE, "nextind")
g["ascii"] = @benchmarkable nextind_benchmarker($ascii_string)
g["unicode"] = @benchmarkable nextind_benchmarker($unicode_string)
g["malformed"] = @benchmarkable nextind_benchmarker($malformed_string)


function getindex_benchmarker(s,step)
    l = ncodeunits(s)
    ret = UInt32(0)
    i=l
    for i = 1:step:l
        ret += reinterpret(UInt32,getindex(s,i))
    end
    return ret
end

g = addgroup!(SUITE, "getindex")
g["1-byte"] = @benchmarkable getindex_benchmarker(s,1) setup=(s = 'J'^1200)
g["2-byte"] = @benchmarkable getindex_benchmarker(s,2) setup=(s = 'Δ'^600)
g["3-byte"] = @benchmarkable getindex_benchmarker(s,3) setup=(s = '￦'^400)
g["4-byte"] = @benchmarkable getindex_benchmarker(s,4) setup=(s = '🚀'^300)

function iterate_benchmarker(s)

    ret = UInt32(0)
    for c in s
        ret += reinterpret(UInt32,c)
    end
    return ret
end

g = addgroup!(SUITE, "iterate")
g["ascii"] = @benchmarkable iterate_benchmarker($ascii_string)
g["unicode"] = @benchmarkable iterate_benchmarker($unicode_string)
g["malformed"] = @benchmarkable iterate_benchmarker($malformed_string)
loadparams!(SUITE, BenchmarkTools.load(PARAMS_PATH)[1], :evals, :samples);

end # module StringBenchmarks