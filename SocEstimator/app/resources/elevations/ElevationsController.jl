module ElevationsController

using Genie.Renderer.Html, SearchLight, SocEstimator.Elevations

  # Build something great
function index()
    html(:elevations, :index, elevations = rand(Elevation))
end
  
end
