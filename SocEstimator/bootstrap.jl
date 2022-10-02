(pwd() != @__DIR__) && cd(@__DIR__) # allow starting app from bin/ dir

using SocEstimator
const UserApp = SocEstimator
SocEstimator.main()
