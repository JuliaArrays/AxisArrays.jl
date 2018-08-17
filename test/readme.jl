# Intended to ensure the README stays working (this is a copy)

using AxisArrays, Unitful
import Unitful: s, ms, µs

fs = 40000
y = randn(60*fs+1)*3
for spk = (sin.(0.8:0.2:8.6) .* [0:0.01:.1; .15:.1:.95; 1:-.05:.05]   .* 50,
           sin.(0.8:0.4:8.6) .* [0:0.02:.1; .15:.1:1; 1:-.2:.1] .* 50)
    i = rand(round(Int,.001fs):1fs)
    while i+length(spk)-1 < length(y)
        y[i:i+length(spk)-1] += spk
        i += rand(round(Int,.001fs):1fs)
    end
end

A = AxisArray([y 2y], Axis{:time}(0s:1s/fs:60s), Axis{:chan}([:c1, :c2]))
A[Axis{:time}(4)]
A[Axis{:chan}(:c2), Axis{:time}(1:5)]
ax = A[40µs .. 220µs, :c1]
AxisArrays.axes(ax, 1)
A[atindex(-90µs .. 90µs, 5), :c2]
idxs = findall(diff(A[:,:c1] .< -15) .> 0)
spks = A[atindex(-200µs .. 800µs, idxs), :c1]
A[atvalue(2.5e-5s), :c1]
A[2.5e-5s..2.5e-5s, :c1]
A[atvalue(25.0µs)]

# # A possible "dynamic verification" strategy
# const readmefile = joinpath(dirname(dirname(@__FILE__)), "README.md")

# function extract_julialines(iowr, filein)
#     open(filein) do iord
#         while !eof(iord)
#             line = readline(iord)
#             if startswith(line, "julia>")
#                 print(iowr, line[8:end])
#                 while !eof(iord)
#                     line = readline(iord)
#                     if !startswith(line, "    ")
#                         break
#                     end
#                     print(iowr, line[8:end])
#                 end
#             end
#         end
#     end
# end

# tmpfile, iowr = mktemp()
# extract_julialines(iowr, readmefile)
# close(iowr)

# include(tmpfile)
# rm(tmpfile)
