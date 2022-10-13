using Geodesy
using CSV
using DataFrames
using Tables

df = CSV.read("df3.csv", DataFrame)

o = Geodesy.LLA(17.398, 78.506, 498.3)
d = Geodesy.LLA(12.9929, 77.692, 896.7)
Geodesy.euclidean_distance(o, d)


tbl = Tables.rowtable(df)

f = x -> Geodesy.LLA(x[2], x[1], x[3])
x_lla = map(f ,Tables.rows(tbl))

f = x -> ECEF(x, wgs84)
x_ecef = map(f, x_lla)

x_ecef = mapreduce(permutedims, vcat, x_ecef)

using Plots;

plot3d(x_ecef[:,2],x_ecef[:,1], x_ecef[:,3])

plot(x_ecef[:,2],x_ecef[:,1])

x_ecef[1,:]

x_ecef
x_lla
using GMT

gmt("mapproject -J+proj=merc", [0 0;10 10;20 20;30 30])
GMT.mapproject([17.4 78.5; 12.9 77.7])