using Genie, Genie.Router, Genie.Renderer.Html, Genie.Requests, ImageMagick,
Base64, Plots

form = """
<form action="/" method="POST" enctype="multipart/form-data">
  <label for="x_start">X left:</label>
  <input type="number" id="x_start" name="x_start">

  <label for="x_end">X right:</label>
  <input type="number" id="x_end" name="x_end"><br/><br/>

  <label for="y_start">Y left:</label>
  <input type="number" id="y_start" name="y_start">

  <label for="y_end">Y right:</label>
  <input type="number" id="y_end" name="y_end"><br/><br/>

  <input type="file" name="yourfile" /><br/><br/>
  <input type="submit" value="Submit" />
</form>
"""

route("/") do
  html(form)
  # serve_static_file("welcome.html")
end

using SocEstimator.EdgeDetector

route("/", method = POST) do
  if infilespayload(:yourfile)
    x_start = parse(Int64, postpayload(:x_start))
    x_end = parse(Int64, postpayload(:x_end))
    y_start = parse(Int64, postpayload(:y_start))
    y_end = parse(Int64, postpayload(:y_end))
    raw = filespayload(:yourfile)
    img = ImageMagick.readblob(raw.data)
    df = EdgeDetector.getdata(img, x_start, y_start, x_end, y_end)
    savefig(plot(df[:,:x], df[:,:y], seriestype = :scatter, markersize = 1, size=(1497,539)), "result.png")
    savefig(plot(df[:,:x], df[:,:soc_used], seriestype = :scatter, markersize = 1, size=(1497,539)), "soc_result.png")
    savefig(plot(df[:,:x], df[:,:wh_per_km], seriestype = :scatter, markersize = 1, size=(1497,539)), "whpkm_result.png")
    
    data_original = Base64.base64encode(raw.data)

    image_stream = open("result.png") # This opens a file, but you can just as well use a in-memory buffer
    data_digitized = Base64.base64encode(image_stream)

    whpkm_image_stream = open("whpkm_result.png") # This opens a file, but you can just as well use a in-memory buffer
    data_whpkm = Base64.base64encode(whpkm_image_stream)

    soc_image_stream = open("soc_result.png") # This opens a file, but you can just as well use a in-memory buffer
    data_soc = Base64.base64encode(soc_image_stream)
    
    html("""
    <h4>Original version</h4>
    <img src="data:image/png;base64,$(data_original)"  alt="Original version" width="1497" height="539">
    <h4>Digitized version</h4>
    <img src="data:image/png;base64,$(data_digitized)" alt="Digitized version" width="1497" height="539">
    <h4>Wh per km</h4>
    <img src="data:image/png;base64,$(data_whpkm)" alt="Digitized version" width="1497" height="539">
    <h4>SoC used</h4>
    <img src="data:image/png;base64,$(data_soc)" alt="Digitized version" width="1497" height="539">""")
    # sprint(show, "text/html", p)
  else
    "No file uploaded"
  end


# route("/", method = POST) do
#   if infilespayload(:yourfile)
#     write(filespayload(:yourfile))
#     typeof(filespayload(:yourfile))
#     # html(getdata(filespayload(:yourfile)))
#     # stat(filename(filespayload(:yourfile)))
#   else
#     "No file upload ed"
#   end
end



# route("/elevations", ElevationsController.index)
