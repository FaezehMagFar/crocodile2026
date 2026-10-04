# Interactive 3D Galveston view

This browser map combines:

- Esri World Imagery satellite tiles;
- OpenStreetMap building footprints and mapped heights delivered by OpenFreeMap;
- Mapterhorn elevation tiles for the 3-D terrain surface and hillshade;
- MapLibre GL JS building extrusion; and
- the maximum newly inundated depth from the SFINCS Hurricane Ike run.

Generate the flood overlay from the SFINCS map output:

```bash
python ../scripts/create_sfincs_3d_city_assets.py --map /path/to/sfincs_map.nc
```

Then serve the repository directory and open the map in a browser:

```bash
python -m http.server 8000
```

Open `http://localhost:8000/ike-mom6-sfincs/interactive/sfincs_3d_city.html`.

The map does not require a paid map token. Buildings without a mapped height use
an 8 m display fallback; their footprints still come from OpenStreetMap.
The full-bay GIF keeps the camera fixed and animates actual SFINCS inundation
from 127 hours before through 65 hours after landfall. It uses hourly frames
near landfall and 3× vertical terrain exaggeration because the Galveston Bay
coast is naturally very flat; the interactive map uses 1.5× by default.
