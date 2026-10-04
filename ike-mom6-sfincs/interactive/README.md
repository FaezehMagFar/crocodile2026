# Interactive 3D Galveston view

This browser map combines:

- Esri World Imagery satellite tiles;
- OpenStreetMap building footprints and mapped heights delivered by OpenFreeMap;
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
