using Genie, Genie.Router, Genie.Renderer.Html, Genie.Requests, ImageMagick,
Base64, Plots

form = """
<form action="/" method="POST" enctype="multipart/form-data">

  <input type="radio" id="oneway" name="way" value="1" checked="checked">
  <label for="oneway">One way</label>
  <input type="radio" id="twoway" name="way" value="2">
  <label for="twoway">Two way</label><br/><br/>

  <label for="x_end">Onward distance:</label>
  <input type="number" id="x_end" name="x_end">km<br/><br/>

  <label for="x_end_return">Return distance:</label>
  <input type="number" id="x_end_return" name="x_end_return" value="0">km<br/><br/>

  <label for="y_start">Starting elevation:</label>
  <input type="number" id="y_start" name="y_start">m<br/><br/>

  <label for="y_end">Ending elevation:</label>
  <input type="number" id="y_end" name="y_end">m<br/><br/>

  <label for="batcap">Battery capacity</label>
  <input type="radio" id="nexy" name="batcap" value="30200">
  <label for="nexy">30.2 kW</label>
  <input type="radio" id="maxi" name="batcap" value="40500" checked="checked">
  <label for="nexy">40.5 kW</label><br/><br/>

  <label for="onwardfile">Onward file</label>
  <input type="file" id="onwardfile" name="onwardfile" />
  <br/><br/>

  <label for="returnfile">Return file</label>
  <input type="file" id="returnfile" name="returnfile" />
  <br/><br/>

  <input type="submit" value="Submit" />

</form>
"""

route("/") do
  html(form)
  # serve_static_file("welcome.html")
end

using SocEstimator.EdgeDetector

route("/", method = POST) do
  way = parse(Int64, postpayload(:way))
  x_start = 0
  x_end = parse(Int64, postpayload(:x_end))
  x_end_return = parse(Int64, postpayload(:x_end_return))
  y_start = parse(Int64, postpayload(:y_start))
  y_end = parse(Int64, postpayload(:y_end))
  bat_cap = parse(Int64, postpayload(:batcap))
  if infilespayload(:onwardfile)
    raw = filespayload(:onwardfile)
    img = ImageMagick.readblob(raw.data)
  else
    "No file uploaded"
  end
  if infilespayload(:returnfile)
    raw_return = filespayload(:returnfile)
    img_return = ImageMagick.readblob(raw_return.data)
  else
    "No file uploaded"
    img_return = img
    x_end_return = x_end
  end

  if x_end_return == 0
    x_end_return = x_end
  end

  df, onward_len = EdgeDetector.getdata(img, x_start, y_start, x_end, y_end, way, bat_cap, x_end_return, img_return)

  if onward_len == size(df,1)
    savefig(plot(df[:,:x], df[:,:y], markersize = 1, size=(1497,539), label="Elevation"), "result.png")
    savefig(plot(df[:,:x], df[:,:soc_used], markersize = 1, size=(1497,539), label="SoC used"), "soc_result.png")
    savefig(plot(df[:,:x], df[:,:wh_per_km], markersize = 1, size=(1497,539), label="Wh/km"), "whpkm_result.png")
  else
    plt = plot(df[:,:x], df[:,:y], markersize = 1, size=(1497,539), label="Elevation")
    scatter!([df[onward_len,:x]], [df[onward_len,:y]], markersize = 3, color="red", marker=:xcross,label="Destination", size=(1497,539))
    savefig(plt, "result.png")
    plt = plot(df[:,:x], df[:,:soc_used], markersize = 1, size=(1497,539), label="SoC used")
    scatter!([df[onward_len,:x]], [df[onward_len,:soc_used]], markersize = 3, color="red", marker=:xcross,label="Destination", size=(1497,539))
    savefig(plt, "soc_result.png")
    plt = plot(df[:,:x], df[:,:wh_per_km], markersize = 1, size=(1497,539), label="Wh/km")
    scatter!([df[onward_len,:x]], [df[onward_len,:wh_per_km]], markersize = 3, color="red", marker=:xcross, label="Destination", size=(1497,539))
    savefig(plt, "whpkm_result.png")
    # savefig(plot(df[:,:x], df[:,:wh_per_km], markersize = 1, size=(1497,539), label="Wh/km"), "whpkm_result.png")
  end
  
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
  <h4>SoC used</h4>
  <img src="data:image/png;base64,$(data_soc)" alt="Digitized version" width="1497" height="539">
  <h4>Wh per km</h4>
  <img src="data:image/png;base64,$(data_whpkm)" alt="Digitized version" width="1497" height="539">""")
  # sprint(show, "text/html", p)
  
end


# route("/", method = POST) do
#   if infilespayload(:onwardfile)
#     write(filespayload(:onwardfile))
#     typeof(filespayload(:onwardfile))
#     # html(getdata(filespayload(:onwardfile)))
#     # stat(filename(filespayload(:onwardfile)))
#   else
#     "No file upload ed"
#   end




# route("/elevations", ElevationsController.index)
