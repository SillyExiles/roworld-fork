#!/usr/bin/env python3
"""Empires Front: builds the empire maps (one per era) and the registry src/shared/Data/MapList.luau.

Terrain: land and lakes from Natural Earth 1:10m (public domain), drawn with make_maps.py's projection;
elevation classes (plains / highland / mountain) read back from RoWorld's earlier continent and World map
modules (their ETOPO1-derived magnitudes; NOAA is not reachable from the build machine), the finest
module covering each point first. The British Empire map keeps the World map's terrain as it is.

Nations are hand-placed: the provinces, kingdoms and peoples of each empire's era, in priority order; one
closer than the map's `min_gap` tiles to one already placed is left out. Flags are the modern flags of
each region (the game's flag atlas).

Usage (repo root): PYTHONPATH=<dir with zstandard> python3 tools/maps/make_empire_maps.py \
    --ne <dir with ne_10m_land.geojson, ne_10m_lakes.geojson> --old <dir with the old map modules> \
    [--only rome,persia] [--preview build/preview]
"""
import argparse
import base64
import importlib.util
import math
import os
import re
import sys

import numpy as np
import zstandard
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
spec_mm = importlib.util.spec_from_file_location("make_maps", os.path.join(HERE, "make_maps.py"))
mm = importlib.util.module_from_spec(spec_mm)
spec_mm.loader.exec_module(mm)

SS = mm.SS
LAND, SHORE, OCEAN = mm.LAND, mm.SHORE, mm.OCEAN

# Extra narrow straits for these windows (lon/lat polylines), on top of make_maps.STRAITS.
EXTRA_STRAITS = [
    [(15.55, 38.30), (15.65, 38.15)],  # Messina
    [(-5.0, 54.9), (-5.3, 55.2)],  # North Channel (narrowest)
]

# --------------------------------------------------------------------------------------------------
# The maps. era: Data/Eras key. Nations: (name, flag, lon, lat), most important first.
# --------------------------------------------------------------------------------------------------
MAPS = [
    dict(id="rome", replicated=True, sites=[("Roma", 12.5, 41.9), ("Carthago", 10.2, 36.85), ("Alexandria", 29.9, 31.2), ("Athenae", 23.7, 38.0), ("Antiochia", 36.2, 36.2)], name="Roman Empire", module="Rome", era="rome", year="117 AD",
         lon0=-12.0, lon1=48.0, lat_top=58.0, lat_bottom=22.0, ppd=27.0, lat_std=40.0, lakes=9,
         categories=["featured", "empire", "antiquity"], frequency=10, modifiers=[], min_gap=42,
         nations=[
             ("Roma", "it", 12.5, 41.9), ("Aegyptus", "eg", 31.2, 30.0), ("Carthago", "tn", 9.8, 36.0),
             ("Achaea", "gr", 22.2, 37.8), ("Syria", "sy", 37.0, 34.8), ("Asia", "tr", 28.0, 38.5),
             ("Hispania", "es", -3.5, 41.5), ("Gallia Lugdunensis", "fr", 2.0, 47.8),
             ("Britannia", "gb", -1.5, 52.5), ("Parthia", "ir", 47.0, 34.0), ("Dacia", "ro", 24.0, 46.0),
             ("Germania Magna", "de", 9.5, 52.5), ("Baetica", "es", -5.0, 37.6), ("Lusitania", "pt", -7.6, 39.6),
             ("Gallia Narbonensis", "fr", 4.0, 43.7), ("Aquitania", "fr", 0.0, 45.2),
             ("Gallia Belgica", "be", 5.0, 49.8), ("Germania Superior", "de", 8.0, 48.4),
             ("Sicilia", "it", 14.2, 37.5), ("Sardinia", "it", 9.0, 40.0), ("Venetia", "it", 11.8, 45.5),
             ("Raetia", "ch", 10.0, 47.2), ("Noricum", "at", 14.2, 47.3), ("Pannonia", "hu", 18.5, 46.6),
             ("Dalmatia", "hr", 17.5, 44.0), ("Moesia", "bg", 24.5, 43.4), ("Thracia", "bg", 26.2, 42.0),
             ("Macedonia", "mk", 21.8, 40.9), ("Creta", "gr", 24.9, 35.25), ("Cyprus", "cy", 33.2, 35.0),
             ("Bithynia", "tr", 31.5, 41.0), ("Galatia", "tr", 33.0, 39.3), ("Cappadocia", "tr", 36.3, 38.6),
             ("Lycia", "tr", 30.6, 36.9), ("Armenia", "am", 44.5, 40.0), ("Mesopotamia", "iq", 41.0, 36.4),
             ("Arabia Petraea", "jo", 36.0, 30.3), ("Cyrenaica", "ly", 22.0, 32.3), ("Numidia", "dz", 6.5, 35.8),
             ("Mauretania", "dz", 2.5, 35.6), ("Tingitana", "ma", -5.5, 34.2), ("Caledonia", "gb", -4.3, 57.0),
             ("Hibernia", "ie", -8.0, 53.2), ("Marcomanni", "cz", 15.0, 49.6), ("Quadi", "sk", 18.6, 48.6),
             ("Gothi", "pl", 19.0, 53.3), ("Vandali", "pl", 16.4, 51.4), ("Aestii", "lt", 23.5, 55.0),
             ("Roxolani", "md", 29.0, 47.2), ("Sarmatia", "ua", 34.0, 48.3), ("Bosporus", "ua", 35.5, 45.2),
             ("Iberia", "ge", 44.0, 42.0), ("Albania Caucasia", "az", 47.5, 40.8), ("Media", "ir", 47.5, 37.6),
             ("Characene", "kw", 47.5, 30.8), ("Hejaz", "sa", 39.5, 25.0), ("Garamantes", "ly", 13.5, 26.5),
             ("Gaetuli", "dz", 3.0, 31.0), ("Mauri", "ma", -6.0, 31.0), ("Blemmyes", "sd", 34.0, 23.5),
             ("Libyes", "eg", 26.5, 27.5), ("Colchis", "ge", 41.8, 42.3), ("Scythia", "ua", 30.5, 50.5),
         ]),
    dict(id="persia", sites=[("Persepolis", 52.9, 29.9), ("Babylon", 44.4, 32.5), ("Memphis", 31.25, 29.85), ("Sardis", 28.0, 38.5), ("Bactra", 66.9, 36.75)], name="Persian Empire", module="Persia", era="persia", year="500 BC",
         lon0=18.0, lon1=78.0, lat_top=48.0, lat_bottom=10.0, ppd=24.0, lat_std=30.0, lakes=9,
         categories=["featured", "empire", "antiquity"], frequency=10, modifiers=[], min_gap=40,
         nations=[
             ("Persis", "ir", 52.9, 29.9), ("Babylonia", "iq", 44.4, 32.5), ("Mudraya", "eg", 31.2, 29.8),
             ("Lydia", "tr", 28.0, 38.5), ("Media", "ir", 48.5, 34.8), ("Bactria", "af", 67.0, 36.7),
             ("Athens", "gr", 23.8, 38.1), ("Sparta", "gr", 22.0, 37.2), ("Macedon", "mk", 22.2, 40.8),
             ("Elam", "ir", 48.6, 31.6), ("Assyria", "iq", 43.2, 36.4), ("Phoenicia", "lb", 35.7, 33.8),
             ("Syria", "sy", 37.8, 35.3), ("Upper Egypt", "eg", 32.6, 25.7), ("Phrygia", "tr", 31.0, 39.3),
             ("Cappadocia", "tr", 35.5, 38.7), ("Cilicia", "tr", 34.9, 37.0), ("Armina", "am", 44.5, 40.2),
             ("Parthava", "tm", 58.0, 37.2), ("Hyrcania", "ir", 54.0, 36.8), ("Aria", "af", 62.2, 34.3),
             ("Sogdia", "uz", 66.9, 39.6), ("Chorasmia", "uz", 60.5, 41.5), ("Drangiana", "ir", 61.5, 31.0),
             ("Arachosia", "af", 65.7, 31.6), ("Gandhara", "pk", 71.5, 34.0), ("Hindush", "pk", 68.5, 26.0),
             ("Gedrosia", "pk", 63.0, 26.5), ("Carmania", "ir", 57.0, 30.3), ("Maka", "om", 57.5, 22.5),
             ("Arabaya", "sa", 39.0, 28.0), ("Putaya", "ly", 21.5, 32.0), ("Kush", "sd", 32.5, 19.0),
             ("Skudra", "bg", 26.0, 42.2), ("Saka", "kg", 72.0, 42.0), ("Massagetae", "kz", 61.0, 45.5),
             ("Scythians", "ua", 34.0, 46.8), ("Epirus", "al", 20.6, 39.8), ("Illyria", "me", 19.5, 42.5),
             ("Saba", "ye", 45.0, 15.5), ("Hadramawt", "ye", 49.0, 15.5), ("D'mt", "er", 38.8, 14.5),
             ("Colchis", "ge", 42.0, 42.2), ("Caucasian Albania", "az", 47.5, 41.0), ("Kuru", "in", 77.2, 29.5),
             ("Avanti", "in", 75.8, 23.2), ("Saurashtra", "in", 70.5, 22.0), ("Asmaka", "in", 77.0, 19.0),
             ("Chera", "in", 76.0, 11.5), ("Dilmun", "bh", 50.5, 26.0), ("Dedan", "sa", 37.9, 26.6),
             ("Qedar", "jo", 38.5, 31.0), ("Yamama", "sa", 46.5, 24.5), ("Thrace", "tr", 27.5, 41.0),
             ("Cyprus", "cy", 33.2, 35.0), ("Getae", "ro", 25.0, 44.8),
         ]),
    dict(id="china", sites=[("Beijing", 116.4, 39.9), ("Nanjing", 118.8, 32.05), ("Xi'an", 108.9, 34.3), ("Guangzhou", 113.3, 23.1), ("Chengdu", 104.1, 30.65)], name="Ming China", module="China", era="china", year="1450",
         lon0=68.0, lon1=146.0, lat_top=56.0, lat_bottom=2.0, ppd=18.0, lat_std=30.0, lakes=9,
         categories=["featured", "empire", "gunpowder"], frequency=10, modifiers=[], min_gap=42,
         nations=[
             ("Beijing", "cn", 116.4, 39.9), ("Nanjing", "cn", 118.8, 32.0), ("Joseon", "kr", 127.0, 37.4),
             ("Ashikaga Japan", "jp", 135.8, 35.0), ("Northern Yuan", "mn", 106.0, 47.0),
             ("Dai Viet", "vn", 105.8, 21.0), ("Ayutthaya", "th", 100.5, 14.6), ("Delhi Sultanate", "in", 77.2, 28.6),
             ("Shandong", "cn", 118.0, 36.4), ("Shanxi", "cn", 112.5, 37.8), ("Henan", "cn", 113.6, 34.0),
             ("Shaanxi", "cn", 108.9, 34.6), ("Sichuan", "cn", 104.0, 30.6), ("Huguang", "cn", 112.5, 29.0),
             ("Jiangxi", "cn", 115.9, 27.3), ("Zhejiang", "cn", 120.2, 29.3), ("Fujian", "cn", 118.0, 25.8),
             ("Guangdong", "cn", 113.3, 23.5), ("Guangxi", "cn", 108.5, 23.8), ("Guizhou", "cn", 106.7, 26.6),
             ("Yunnan", "cn", 102.0, 25.0), ("Liaodong", "cn", 123.0, 41.5), ("Gansu", "cn", 103.8, 36.4),
             ("Hamgyong", "kp", 128.5, 41.0), ("Kanto", "jp", 139.7, 36.0), ("Kyushu", "jp", 130.7, 32.8),
             ("Tohoku", "jp", 140.9, 39.5), ("Ezo", "jp", 142.8, 43.3), ("Ryukyu", "jp", 127.8, 26.4),
             ("Jianzhou Jurchens", "cn", 127.0, 44.0), ("Haixi Jurchens", "cn", 125.5, 47.5),
             ("Wild Jurchens", "ru", 135.0, 48.5), ("Oirats", "mn", 92.0, 47.0), ("Uriankhai", "cn", 118.5, 45.0),
             ("Ordos", "cn", 108.5, 39.5), ("Moghulistan", "kz", 80.0, 43.0), ("Kara Del", "cn", 93.5, 42.6),
             ("Turpan", "cn", 88.8, 42.9), ("Kashgar", "cn", 76.0, 39.5), ("Khotan", "cn", 80.5, 37.0),
             ("Timurids", "uz", 69.5, 40.0), ("Kabul", "af", 69.2, 34.5), ("U-Tsang", "cn", 91.1, 29.6),
             ("Kham", "cn", 97.5, 31.0), ("Amdo", "cn", 100.5, 35.0), ("Ngari", "cn", 81.0, 32.0),
             ("Jaunpur", "in", 82.6, 25.7), ("Bengal", "bd", 89.5, 23.5), ("Bahmani", "in", 77.0, 17.5),
             ("Vijayanagara", "in", 76.5, 14.0), ("Gujarat", "in", 72.6, 23.0), ("Malwa", "in", 76.5, 23.0),
             ("Orissa", "in", 85.0, 20.5), ("Kashmir", "in", 74.8, 34.1), ("Multan", "pk", 71.5, 30.2),
             ("Sindh", "pk", 68.8, 25.5), ("Kotte", "lk", 80.6, 7.5), ("Nepal", "np", 85.3, 27.7),
             ("Ahom", "in", 94.0, 26.8), ("Champa", "vn", 108.6, 14.0), ("Lan Xang", "la", 102.6, 19.9),
             ("Lan Na", "th", 99.0, 18.8), ("Khmer", "kh", 104.9, 12.5), ("Ava", "mm", 96.0, 21.9),
             ("Hanthawaddy", "mm", 96.5, 17.3), ("Arakan", "mm", 93.5, 20.5), ("Malacca", "my", 102.0, 3.5),
             ("Samudera Pasai", "id", 97.0, 4.5), ("Brunei", "bn", 114.9, 4.6), ("Tondo", "ph", 121.0, 14.8),
             ("Cebu", "ph", 123.9, 10.3), ("Maguindanao", "ph", 124.5, 7.2),
         ]),
    dict(id="spain", sites=[("Sevilla", -6.0, 37.4), ("Havana", -82.4, 23.1), ("Mexico City", -99.1, 19.4), ("Potosi", -65.75, -19.6), ("Lima", -77.0, -12.05)], name="Spanish Empire", module="Spain", era="spain", year="1580",
         lon0=-125.0, lon1=12.0, lat_top=56.0, lat_bottom=-56.0, ppd=9.0, lat_std=0.0, lakes=9,
         categories=["featured", "empire", "age_of_sail"], frequency=10, modifiers=[], min_gap=34,
         nations=[
             ("Castile", "es", -3.7, 40.4), ("New Spain", "mx", -99.1, 19.4), ("Peru", "pe", -77.0, -12.0),
             ("England", "gb", -1.5, 52.5), ("France", "fr", 2.5, 47.0), ("Portugal", "pt", -8.2, 39.6),
             ("Brazil", "br", -38.8, -12.9), ("Dutch Republic", "nl", 5.3, 52.3), ("Morocco", "ma", -6.0, 32.0),
             ("Aragon", "es", -0.9, 41.6), ("Andalusia", "es", -5.5, 37.6), ("Galicia", "es", -8.0, 42.8),
             ("Nueva Galicia", "mx", -103.3, 20.7), ("Yucatan", "mx", -89.0, 20.3), ("Guatemala", "gt", -90.5, 14.6),
             ("Cuba", "cu", -79.0, 22.0), ("Hispaniola", "do", -70.5, 19.0), ("Puerto Rico", "pr", -66.5, 18.2),
             ("Florida", "us", -81.5, 28.5), ("Panama", "pa", -80.0, 8.5), ("New Granada", "co", -74.1, 4.6),
             ("Venezuela", "ve", -66.9, 9.5), ("Quito", "ec", -78.5, -1.0), ("Cusco", "pe", -72.0, -13.8),
             ("Charcas", "bo", -65.7, -19.6), ("Chile", "cl", -70.7, -33.4), ("Tucuman", "ar", -65.2, -26.8),
             ("Asuncion", "py", -57.6, -25.3), ("Buenos Aires", "ar", -60.0, -34.6), ("Pernambuco", "br", -36.5, -8.0),
             ("Sao Vicente", "br", -46.5, -23.0), ("Spanish Netherlands", "be", 4.5, 50.7), ("Ireland", "ie", -8.0, 53.0),
             ("Algiers", "dz", 3.0, 35.5), ("Tunis", "tn", 9.8, 35.5), ("Milan", "it", 9.2, 45.2),
             ("Sardinia", "it", 9.0, 40.0), ("Songhai", "ml", -3.0, 16.5), ("Jolof", "sn", -15.5, 15.3),
             ("Benin", "ng", 5.6, 7.3), ("Mali", "gn", -9.5, 11.5), ("Mapuche", "cl", -72.5, -38.5),
             ("Tehuelche", "ar", -68.5, -46.0), ("Chichimeca", "mx", -101.5, 23.5), ("Pueblo", "us", -106.5, 35.0),
             ("Powhatan", "us", -77.5, 37.5), ("Iroquois", "us", -75.5, 42.8), ("Cherokee", "us", -84.0, 35.3),
             ("Muscogee", "us", -86.0, 32.5), ("Caddo", "us", -94.5, 32.5), ("Wichita", "us", -98.0, 37.5),
             ("Chumash", "california", -119.5, 35.5), ("Miskito", "ni", -84.5, 13.5), ("Omagua", "br", -66.0, -3.5),
             ("Tapajos", "br", -55.0, -3.5), ("Charrua", "uy", -56.0, -32.5), ("Guarani", "br", -51.5, -27.5),
             ("Tupi", "br", -48.0, -15.0), ("Apache", "us", -104.0, 31.0), ("Lakota", "us", -100.5, 44.5),
             ("Huron", "ca", -80.5, 45.0), ("Mi'kmaq", "ca", -65.5, 46.0), ("Gran Chaco", "py", -60.5, -22.0),
             ("Guiana", "gy", -58.5, 4.5), ("Tierra del Fuego", "ar", -68.5, -54.0),
         ]),
    dict(id="mongol", sites=[("Karakorum", 102.8, 47.2), ("Khanbaliq", 116.4, 39.9), ("Samarkand", 66.9, 39.6), ("Baghdad", 44.4, 33.3), ("Kiev", 30.5, 50.4)], name="Mongol Empire", module="Mongol", era="mongol", year="1279",
         lon0=22.0, lon1=142.0, lat_top=62.0, lat_bottom=18.0, ppd=13.0, lat_std=42.0, lakes=9,
         categories=["featured", "empire", "medieval"], frequency=10, modifiers=[], min_gap=34,
         nations=[
             ("Karakorum", "mn", 102.8, 47.2), ("Yuan Dynasty", "cn", 116.4, 39.9), ("Golden Horde", "kz", 47.5, 48.5),
             ("Ilkhanate", "ir", 46.3, 38.1), ("Chagatai Khanate", "kz", 80.5, 44.0), ("Mamluk Sultanate", "eg", 31.2, 30.0),
             ("Byzantine Empire", "gr", 28.9, 41.0), ("Goryeo", "kr", 127.0, 37.5), ("Kamakura Japan", "jp", 135.5, 34.9),
             ("Delhi Sultanate", "in", 77.2, 28.6), ("Dai Viet", "vn", 105.8, 21.0), ("Pagan", "mm", 95.0, 21.2),
             ("Blue Horde", "kz", 66.0, 49.0), ("Sakya Tibet", "cn", 88.9, 29.3), ("Sultanate of Rum", "tr", 32.5, 37.9),
             ("Georgia", "ge", 44.8, 41.7), ("Cilician Armenia", "am", 35.3, 37.1), ("Kiev", "ua", 30.5, 50.4),
             ("Vladimir-Suzdal", "ru", 40.4, 56.1), ("Novgorod", "ru", 31.3, 58.5), ("Hungary", "hu", 22.6, 47.5),
             ("Volga Bulgaria", "ru", 49.1, 54.9), ("Khwarazm", "uz", 60.6, 41.5), ("Samarkand", "uz", 66.9, 39.6),
             ("Herat", "af", 62.2, 34.3), ("Qocho Uyghurs", "cn", 89.2, 42.9), ("Western Xia", "cn", 106.0, 38.5),
             ("Liaoyang", "cn", 123.2, 41.3), ("Jurchen Lands", "cn", 129.0, 46.0), ("Henan", "cn", 113.6, 34.6),
             ("Sichuan", "cn", 104.0, 30.6), ("Yunnan", "cn", 102.7, 25.0), ("Jiangxi", "cn", 115.9, 28.7),
             ("Huguang", "cn", 112.6, 28.2), ("Fujian", "cn", 119.0, 26.1), ("Guangdong", "cn", 113.3, 23.3),
             ("Shaanxi", "cn", 108.9, 34.3), ("Shandong", "cn", 117.5, 36.6), ("Baghdad", "iq", 44.4, 33.3),
             ("Isfahan", "ir", 51.7, 32.7), ("Khorasan", "ir", 59.6, 36.3), ("Bashkirs", "ru", 56.0, 54.0),
             ("Crimea", "ua", 34.3, 45.0), ("Hormuz", "ir", 56.3, 27.4), ("Hejaz", "sa", 39.8, 22.5),
             ("Kashmir", "in", 74.8, 34.1), ("Bengal", "bd", 89.5, 23.6), ("Nepal", "np", 85.3, 27.7),
             ("Syria", "sy", 36.6, 34.5), ("Oirat Lands", "mn", 92.0, 49.5), ("Khitan Steppe", "mn", 114.0, 46.0),
             ("Siberian Tribes", "ru", 84.0, 56.5), ("Gujarat", "in", 72.6, 23.0), ("Najd", "sa", 45.0, 24.5),
             ("Song Remnants", "cn", 120.2, 30.3),
         ]),
    dict(id="ottoman", sites=[("Constantinople", 28.98, 41.0), ("Cairo", 31.2, 30.05), ("Baghdad", 44.4, 33.3), ("Buda", 19.05, 47.5), ("Algiers", 3.06, 36.75)], name="Ottoman Empire", module="Ottoman", era="ottoman", year="1566",
         lon0=-2.0, lon1=58.0, lat_top=50.0, lat_bottom=12.0, ppd=22.0, lat_std=32.0, lakes=9,
         categories=["featured", "empire", "gunpowder"], frequency=10, modifiers=[], min_gap=40,
         nations=[
             ("Rumelia", "tr", 28.9, 41.1), ("Anatolia", "tr", 32.8, 39.9), ("Egypt", "eg", 31.2, 30.0),
             ("Safavid Persia", "ir", 46.3, 38.1), ("Habsburg Austria", "at", 16.4, 48.2), ("Venice", "it", 12.3, 45.5),
             ("Baghdad", "iq", 44.4, 33.3), ("Damascus", "sy", 36.3, 33.5), ("Bosnia", "ba", 18.4, 43.9),
             ("Budin", "hu", 19.0, 47.5), ("Wallachia", "ro", 26.1, 44.4), ("Moldavia", "md", 27.6, 47.2),
             ("Crimean Khanate", "ua", 34.1, 44.9), ("Algiers", "dz", 3.0, 36.6), ("Tunis", "tn", 10.0, 36.6),
             ("Tripoli", "ly", 13.2, 32.8), ("Hejaz", "sa", 39.8, 21.6), ("Yemen", "ye", 44.2, 15.4),
             ("Basra", "iq", 47.8, 30.6), ("Erzurum", "tr", 41.3, 39.9), ("Cyprus", "cy", 33.3, 35.1),
             ("Crete", "gr", 24.9, 35.25), ("Papal States", "it", 12.5, 42.4), ("Naples", "it", 15.5, 40.8),
             ("Sicily", "it", 14.2, 37.5), ("Poland-Lithuania", "pl", 22.5, 49.4), ("Isfahan", "ir", 51.7, 32.7),
             ("Georgia", "ge", 44.8, 41.7), ("Tlemcen", "dz", -0.8, 34.8), ("Abyssinia", "et", 38.6, 13.6),
             ("Funj Sultanate", "sd", 33.0, 14.5), ("Ragusa", "hr", 18.1, 42.7), ("Transylvania", "ro", 23.6, 46.8),
             ("Smederevo", "rs", 20.9, 44.6), ("Morea", "gr", 22.4, 37.5), ("Mosul", "iq", 43.1, 36.3),
             ("Diyarbakir", "tr", 40.2, 37.9), ("Karaman", "tr", 33.2, 37.2), ("Al-Hasa", "sa", 49.6, 25.4),
             ("Oman", "om", 56.8, 23.0), ("Najd", "sa", 45.0, 24.5), ("Bornu", "ng", 13.2, 13.6),
             ("Fezzan", "ly", 14.4, 26.0), ("Darfur", "sd", 25.3, 13.6), ("Genoa", "it", 8.9, 44.4),
             ("France", "fr", 4.8, 45.8), ("Aragon", "es", -0.9, 41.6), ("Sardinia", "it", 9.0, 40.0),
             ("Bohemia", "cz", 14.4, 49.5), ("Croatia", "hr", 15.9, 45.6), ("Sinai", "eg", 33.8, 29.5),
             ("Upper Egypt", "eg", 32.6, 25.7), ("Nubia", "sd", 31.5, 19.5), ("Kurdistan", "iq", 45.0, 36.0),
         ]),
    dict(id="greece", sites=[("Athenai", 23.73, 37.98), ("Sparta", 22.43, 37.07), ("Korinthos", 22.93, 37.94), ("Thebai", 23.32, 38.32), ("Syrakousai", 15.29, 37.07)], name="Ancient Greece", module="Greece", era="greece", year="431 BC",
         lon0=11.0, lon1=36.0, lat_top=43.5, lat_bottom=33.5, ppd=52.0, lat_std=38.5, lakes=9,
         categories=["featured", "empire", "antiquity"], frequency=10, modifiers=[], min_gap=26,
         nations=[
             ("Athenai", "gr", 23.73, 37.98), ("Sparta", "gr", 22.43, 37.07), ("Korinthos", "gr", 22.93, 37.94),
             ("Thebai", "gr", 23.32, 38.32), ("Argos", "gr", 22.72, 37.63), ("Makedonia", "gr", 22.5, 40.6),
             ("Thessalia", "gr", 22.4, 39.5), ("Epeiros", "gr", 20.8, 39.6), ("Aitolia", "gr", 21.6, 38.7),
             ("Phokis", "gr", 22.5, 38.5), ("Achaia", "gr", 21.9, 38.1), ("Elis", "gr", 21.4, 37.7),
             ("Messenia", "gr", 21.9, 37.1), ("Arkadia", "gr", 22.2, 37.5), ("Megara", "gr", 23.35, 38.0),
             ("Euboia", "gr", 23.8, 38.6), ("Chalkidike", "gr", 23.4, 40.3), ("Thrake", "bg", 25.5, 41.4),
             ("Byzantion", "tr", 28.9, 41.0), ("Lydia", "tr", 28.0, 38.5), ("Ionia", "tr", 27.2, 38.0),
             ("Karia", "tr", 28.0, 37.2), ("Phrygia", "tr", 30.5, 39.0), ("Lykia", "tr", 29.6, 36.6),
             ("Pisidia", "tr", 31.0, 37.8), ("Bithynia", "tr", 30.0, 40.6), ("Troas", "tr", 26.6, 39.8),
             ("Kreta", "gr", 24.9, 35.25), ("Rhodos", "gr", 28.0, 36.2), ("Kypros", "cy", 33.3, 35.1),
             ("Lesbos", "gr", 26.3, 39.2), ("Chios", "gr", 26.0, 38.4), ("Samos", "gr", 26.8, 37.7),
             ("Naxos", "gr", 25.4, 37.1), ("Kerkyra", "gr", 19.9, 39.6), ("Illyria", "al", 19.8, 41.3),
             ("Paionia", "mk", 21.7, 41.6), ("Odrysia", "bg", 24.7, 42.4), ("Syrakousai", "it", 15.29, 37.07),
             ("Akragas", "it", 13.6, 37.3), ("Taras", "it", 17.2, 40.5), ("Kroton", "it", 17.1, 39.1),
             ("Rhegion", "it", 15.7, 38.1), ("Kyrene", "ly", 21.86, 32.8), ("Lokris", "gr", 22.9, 38.7),
             ("Akarnania", "gr", 21.2, 38.8), ("Dodekanesa", "gr", 27.0, 36.9), ("Pamphylia", "tr", 30.8, 37.0),
             ("Kilikia", "tr", 34.6, 36.9), ("Kappadokia", "tr", 34.8, 38.6), ("Galatia", "tr", 32.8, 39.9),
         ]),
    dict(id="japan", sites=[("Kyoto", 135.77, 35.01), ("Owari", 136.9, 35.18), ("Kai", 138.57, 35.66), ("Echigo", 138.25, 37.4), ("Satsuma", 130.55, 31.6)], name="Sengoku Japan", module="Japan", era="japan", year="1560",
         lon0=128.5, lon1=146.0, lat_top=45.6, lat_bottom=30.6, ppd=60.0, lat_std=37.0, lakes=9,
         categories=["featured", "empire", "gunpowder"], frequency=10, modifiers=[], min_gap=20,
         nations=[
             ("Ashikaga Shogunate", "jp", 135.77, 35.01), ("Oda", "jp", 136.9, 35.18), ("Takeda", "jp", 138.57, 35.66),
             ("Uesugi", "jp", 138.25, 37.4), ("Imagawa", "jp", 138.38, 34.97), ("Hojo", "jp", 139.15, 35.25),
             ("Mori", "jp", 132.46, 34.4), ("Shimazu", "jp", 130.55, 31.6), ("Otomo", "jp", 131.6, 33.24),
             ("Chosokabe", "jp", 133.53, 33.56), ("Date", "jp", 140.87, 38.27), ("Asai", "jp", 136.27, 35.38),
             ("Asakura", "jp", 136.22, 36.06), ("Saito", "jp", 136.76, 35.42), ("Miyoshi", "jp", 135.5, 34.69),
             ("Tokugawa", "jp", 137.17, 34.95), ("Amago", "jp", 133.05, 35.47), ("Ryuzoji", "jp", 130.3, 33.26),
             ("Mogami", "jp", 140.34, 38.25), ("Nanbu", "jp", 141.15, 40.5), ("Satake", "jp", 140.47, 36.37),
             ("Satomi", "jp", 140.1, 35.0), ("Hatakeyama", "jp", 136.9, 36.75), ("Jinbo", "jp", 137.2, 36.7),
             ("Kitabatake", "jp", 136.5, 34.5), ("Ise", "jp", 136.7, 34.4), ("Ikko-ikki", "jp", 136.6, 36.55),
             ("Kono", "jp", 132.77, 33.84), ("Ito", "jp", 131.42, 31.9), ("Sagara", "jp", 130.76, 32.2),
             ("Murakami Pirates", "jp", 133.0, 34.2), ("Ukita", "jp", 133.93, 34.66), ("Akamatsu", "jp", 134.69, 34.83),
             ("Tsutsui", "jp", 135.8, 34.68), ("Isshiki", "jp", 135.2, 35.5), ("Takeda of Wakasa", "jp", 135.75, 35.5),
             ("Ogasawara", "jp", 137.97, 36.24), ("Murakami", "jp", 138.3, 36.6), ("Utsunomiya", "jp", 139.88, 36.55),
             ("Ashina", "jp", 139.93, 37.49), ("Soma", "jp", 140.92, 37.8), ("Kakizaki", "jp", 140.1, 41.8),
             ("Ainu of Ezo", "jp", 142.5, 43.3), ("Ryukyu", "jp", 129.5, 31.0), ("Joseon", "kr", 129.0, 35.5),
             ("Tsushima So", "jp", 129.3, 34.3), ("Kiso", "jp", 137.7, 35.85), ("Toki", "jp", 137.2, 35.6),
         ]),
]


# Arid land (deserts and dry steppe): (lon, lat, x radius, y radius in degrees) ellipses, their edges
# roughened with noise. Marked with bit 5 (0x20) of a land tile byte, which the game leaves unused on
# land (WorldMap: bit 5 is the ocean bit of WATER tiles); the map renderer paints it as sand / steppe.
DESERTS = [
    (-4.0, 23.0, 21.0, 7.5), (15.0, 23.5, 15.0, 7.0), (27.0, 26.0, 7.5, 4.5),  # Sahara
    (45.5, 22.5, 10.0, 7.0), (40.0, 32.0, 4.5, 2.5),  # Arabia, Syrian desert
    (56.5, 32.5, 5.5, 3.0), (63.0, 29.5, 3.5, 2.0),  # Iranian plateau, Sistan
    (71.5, 26.8, 3.0, 2.3),  # Thar
    (60.5, 41.5, 7.5, 3.8),  # Karakum, Kyzylkum
    (66.0, 47.5, 16.0, 2.8),  # dry Kazakh steppe
    (83.0, 39.0, 6.0, 2.2), (91.0, 40.5, 3.5, 2.0),  # Taklamakan, Lop Nur
    (105.0, 42.5, 10.5, 3.2),  # Gobi
    (19.5, -23.5, 5.0, 4.5), (14.5, -22.0, 1.6, 6.0),  # Kalahari, Namib
    (132.5, -25.0, 13.0, 6.0),  # Australian outback
    (-111.0, 32.0, 6.5, 5.0), (-103.5, 28.5, 3.0, 3.5),  # Sonoran / Mojave, Chihuahuan
    (-69.8, -23.0, 1.6, 5.5),  # Atacama
    (-67.5, -44.0, 3.5, 6.0),  # Patagonian steppe
    (46.0, 7.0, 5.5, 4.5),  # Horn of Africa
    (-64.0, -30.0, 2.5, 3.0),  # Monte
]


def lonlat_grid(proj, w, h):
    xs = np.arange(w) + 0.5
    ys = np.arange(h) + 0.5
    lon1, _ = proj.unproject(xs, np.zeros_like(xs))
    _, lat1 = proj.unproject(np.zeros_like(ys), ys)
    return np.broadcast_to(lon1[None, :], (h, w)), np.broadcast_to(lat1[:, None], (h, w))


def apply_arid(proj, grid):
    """Tile bytes with bit 5 set on arid land (cleared on the rest of the land)."""
    h, w = grid.shape
    lon, lat = lonlat_grid(proj, w, h)
    rng = np.random.default_rng(7)
    noise = ndimage.zoom(rng.random((h // 16 + 2, w // 16 + 2)), 16, order=1)[:h, :w]
    score = np.zeros((h, w))
    for clon, clat, rx, ry in DESERTS:
        d = ((lon - clon) / rx) ** 2 + ((lat - clat) / ry) ** 2
        score = np.maximum(score, 1.0 - d)
    arid = score + (noise - 0.5) * 0.45 > 0.0
    land = ((grid & LAND) != 0) & (grid != 0x9F)
    out = grid.copy()
    out[land] &= ~np.uint8(0x20)
    out[land & arid] |= 0x20
    return out


# --------------------------------------------------------------------------------------------------
# Elevation from the old modules
# --------------------------------------------------------------------------------------------------
def read_module(path):
    s = open(path, encoding="utf-8").read()
    w = int(re.search(r"\bwidth = (\d+)", s).group(1))
    h = int(re.search(r"\bheight = (\d+)", s).group(1))
    t = re.search(r'\bterrain = "([^"]+)"', s).group(1)
    raw = zstandard.ZstdDecompressor().decompress(base64.b64decode(t), max_output_size=w * h)
    return w, h, np.frombuffer(raw, np.uint8).reshape(h, w), s


class ElevSource:
    """One old map: its land magnitudes (water filled with the nearest land's) on its projection."""

    def __init__(self, spec, path):
        w, h, grid, _ = read_module(path)
        self.proj = mm.Proj(dict(spec, width=w, height=h))
        self.ppd = spec["ppd"]
        land = (grid & LAND) != 0
        mag = (grid & 0x1F).astype(np.float64)
        mag[~land] = 0
        _, (iy, ix) = ndimage.distance_transform_edt(~land, return_indices=True)
        self.mag = mag[iy, ix]
        self.w, self.h = w, h

    def sample(self, lon, lat):
        x, y = self.proj.project(lon, lat)
        if self.proj.world:
            x = np.mod(x, self.w)
        ok = (x >= 0) & (x < self.w) & (y >= 0) & (y < self.h)
        xi = np.clip(x.astype(np.int64), 0, self.w - 1)
        yi = np.clip(y.astype(np.int64), 0, self.h - 1)
        return np.where(ok, self.mag[yi, xi], np.nan)


def mag_to_m(m):
    """Inverse of make_maps.magnitude (midpoint of each class step)."""
    m = m + 0.5
    return np.where(m < 10, m * 30.0, np.where(m < 20, 300 + (m - 10) * 90.0, 1200 + (m - 20) * 280.0))


def load_sources(old_dir):
    out = []
    for spec in mm.MAPS:
        name = spec["module"] + ".luau"
        path = os.path.join(old_dir, name)
        if os.path.exists(path):
            out.append(ElevSource(spec, path))
    out.sort(key=lambda s: -s.ppd)  # finest first
    return out


def elevation_samples(sources, proj):
    xs = (np.arange(proj.w * SS) + 0.5) / SS
    ys = (np.arange(proj.h * SS) + 0.5) / SS
    lon1, _ = proj.unproject(xs, np.zeros_like(xs))
    _, lat1 = proj.unproject(np.zeros_like(ys), ys)
    lon = np.broadcast_to(lon1[None, :], (len(ys), len(xs)))
    lat = np.broadcast_to(lat1[:, None], (len(ys), len(xs)))
    mag = np.full(lon.shape, np.nan)
    for src in sources:
        hole = np.isnan(mag)
        if not hole.any():
            break
        mag[hole] = src.sample(lon[hole], lat[hole])
    mag = np.nan_to_num(mag, nan=2.0)
    return mag_to_m(mag)


# --------------------------------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------------------------------
def pick_nations(proj, grid, spec):
    gap2 = spec["min_gap"] ** 2
    picked, dropped = [], []
    for name, flag, lon, lat in spec["nations"]:
        spot = mm.place(proj, grid, lon, lat)
        if spot is None:
            dropped.append((name, "off map / no land"))
            continue
        near = [n for n in picked if (spot[0] - n["x"]) ** 2 + (spot[1] - n["y"]) ** 2 < gap2]
        if near:
            dropped.append((name, "too close to " + near[0]["name"]))
            continue
        picked.append({"name": name, "flag": flag, "x": spot[0], "y": spot[1], "lon": lon, "lat": lat})
    return picked, dropped


def place_sites(proj, grid, spec):
    out = []
    for name, lon, lat in spec["sites"]:
        x, y = proj.project(lon, lat)
        x = int(x) % proj.w if proj.world else int(x)
        spot = mm.nearest_inland(grid, x, int(y), radius=60)
        if spot is None:
            raise SystemExit("site %s has no land near it" % name)
        out.append({"name": name, "x": spot[0], "y": spot[1]})
    return out


def patch_sites(spec, old_dir):
    """Rewrites a built module with fresh nations and sites, terrain untouched."""
    w, h, grid, text = read_module(module_path(spec))
    proj = mm.Proj(dict(spec, width=w, height=h))
    grid = apply_arid(proj, grid)
    b64 = base64.b64encode(zstandard.ZstdCompressor(level=19).compress(grid.tobytes())).decode("ascii")
    land_tiles = int(re.search(r"\bland_tiles = (\d+)", text).group(1))
    nations, _ = pick_nations(proj, grid, spec)
    write_module(spec, w, h, b64, land_tiles, nations, place_sites(proj, grid, spec))
    return spec, w, h, land_tiles, len(nations)


def module_path(spec):
    if spec.get("replicated") or spec.get("world"):
        return os.path.join(REPO, "src", "shared", "Data", "Maps", spec["module"] + ".luau")
    return os.path.join(REPO, "src", "server", "MapData", spec["module"] + ".luau")


def write_module(spec, w, h, tiles_b64, land_tiles, nations, sites):
    L = mm.lua_str
    lines = [
        "-- GENERATED by tools/maps/make_empire_maps.py (Natural Earth land and lakes; elevation classes from",
        "-- NOAA ETOPO1 via RoWorld's earlier maps; all public domain). Do not edit.",
        "-- terrain = base64(zstd(width * height bytes)), the tile byte format of WorldMap.luau.",
        "return {",
        "\tid = %s," % L(spec["id"]),
        "\tname = %s," % L(spec["name"]),
        "\tmodule = %s," % L(spec["module"]),
        "\tera = %s," % L(spec["era"]),
        "\tyear = %s," % L(spec["year"]),
        "\twidth = %d," % w,
        "\theight = %d," % h,
        "\tk_lin = 1.0,",
        "\tlat_top = %.4f," % spec["lat_top"],
        "\tlat_bottom = %.4f," % (spec["lat_top"] - h / spec["ppd"]),
        "\tcategories = %s," % mm.lua_list(spec["categories"]),
        "\tmultiplayer_frequency = %d," % spec["frequency"],
        "\tforced_modifiers = %s," % mm.lua_list(spec["modifiers"]),
        "\tland_tiles = %d," % land_tiles,
        "\tnations = {",
    ]
    for n in nations:
        lines.append("\t\t{ name = %s, flag = %s, x = %d, y = %d }," % (L(n["name"]), L(n["flag"]), n["x"], n["y"]))
    lines.append("\t},")
    lines.append("\tsites = {")
    for st in sites:
        lines.append("\t\t{ name = %s, x = %d, y = %d }," % (L(st["name"]), st["x"], st["y"]))
    lines += ["\t},", '\tcodec = "zstd+base64",', "\tsize = %d," % (w * h), '\tterrain = "%s",' % tiles_b64, "}", ""]
    os.makedirs(os.path.dirname(module_path(spec)), exist_ok=True)
    with open(module_path(spec), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def build(spec, ne_dir, sources, old_dir, preview):
    if spec.get("reuse_world"):
        w, h, grid, text = read_module(os.path.join(old_dir, "World.luau"))
        proj = mm.Proj(dict(spec, width=w, height=h))
        b64 = re.search(r'\bterrain = "([^"]+)"', text).group(1)
        land_tiles = int(re.search(r"\bland_tiles = (\d+)", text).group(1))
    else:
        proj = mm.Proj(spec)
        w, h = proj.w, proj.h
        land_s = mm.land_samples(ne_dir, proj, spec)
        elev_s = elevation_samples(sources, proj)
        frac = land_s.reshape(h, SS, w, SS).mean(axis=(1, 3))
        land = frac > 0.5
        mm.carve_straits(proj, land)
        saved = mm.STRAITS
        mm.STRAITS = EXTRA_STRAITS
        mm.carve_straits(proj, land)
        mm.STRAITS = saved
        filled = mm.tidy(land)
        elev_sum = np.where(land_s, elev_s, 0).reshape(h, SS, w, SS).sum(axis=(1, 3))
        elev = elev_sum / np.maximum(land_s.reshape(h, SS, w, SS).sum(axis=(1, 3)), 1)
        elev = np.where(land_s.reshape(h, SS, w, SS).any(axis=(1, 3)), elev, mag_to_m(np.full_like(elev, 2.0)))
        mag = mm.magnitude(elev)
        for _ in range(6):
            near = ndimage.grey_dilation(np.where(filled, 0, mag), footprint=mm.FOUR)
            mag = np.where(filled, np.maximum(mag, near), mag)
        typed = np.where(land, LAND | mag, 0).astype(np.uint8)
        tiles = mm.postprocess(typed.tobytes(), w, h)
        grid = np.frombuffer(tiles, np.uint8).reshape(h, w)
        land_tiles = int(land.sum())
        z = zstandard.ZstdCompressor(level=19).compress(tiles)
        b64 = base64.b64encode(z).decode("ascii")
    grid = apply_arid(proj, grid)
    b64 = base64.b64encode(zstandard.ZstdCompressor(level=19).compress(grid.tobytes())).decode("ascii")
    nations, dropped = pick_nations(proj, grid, spec)
    sites = place_sites(proj, grid, spec)
    write_module(spec, w, h, b64, land_tiles, nations, sites)
    print("%-15s %dx%d  %d land tiles  %d nations  %d KB" % (spec["name"], w, h, land_tiles, len(nations), len(b64) // 1024))
    for name, why in dropped:
        print("    dropped %s (%s)" % (name, why))
    if preview:
        m = grid & 0x1F
        img = np.zeros((h, w, 3), np.uint8)
        water = (grid & LAND) == 0
        img[water] = np.stack([20 + 0 * m[water], 60 - m[water], 110 - m[water] * 2], -1)
        img[water & ((grid & OCEAN) == 0)] = (70, 140, 210)
        lm = ~water
        img[lm] = np.stack([70 + m[lm] * 5, 130 - m[lm], 60 + m[lm] * 2], -1).clip(0, 255)
        im = Image.fromarray(img)
        d = ImageDraw.Draw(im)
        for n in nations:
            d.rectangle([n["x"] - 3, n["y"] - 3, n["x"] + 3, n["y"] + 3], fill=(255, 255, 255))
            d.text((n["x"] + 5, n["y"] - 6), n["name"], fill=(255, 255, 255))
        os.makedirs(preview, exist_ok=True)
        im.save(os.path.join(preview, spec["id"] + ".png"))
    return spec, w, h, land_tiles, len(nations)


def write_registry(rows):
    L = mm.lua_str
    lines = [
        "-- GENERATED by tools/maps/make_empire_maps.py. Do not edit.",
        "-- Registry of the playable maps: one empire per map, each played in its own era (Data/Eras).",
        "-- Terrain lives in src/server/MapData/<module>.luau (server only; clients fetch it through MapFetch)",
        "-- except the British Empire's (World), replicated in src/shared/Data/Maps so the title screen and",
        "-- solo games start at once.",
        "local MapList = {}",
        "",
        'MapList.DEFAULT = "rome"',
        'MapList.LICENSE = "Public domain"',
        'MapList.ATTRIBUTION = "Natural Earth, NOAA"',
        'MapList.CREDITS = "Maps made with Natural Earth and NOAA ETOPO1 data (public domain)."',
        "",
        "--- {id, name, module, era, year, width, height, k_lin, categories, multiplayer_frequency,",
        "--- forced_modifiers, land_tiles, nations (count), replicated} in play order.",
        "MapList.maps = {",
    ]
    for spec, w, h, land_tiles, n in rows:
        f = ["id = %s" % L(spec["id"]), "name = %s" % L(spec["name"]), "module = %s" % L(spec["module"]),
             "era = %s" % L(spec["era"]), "year = %s" % L(spec["year"]), "width = %d" % w, "height = %d" % h,
             "k_lin = 1.0", "categories = %s" % mm.lua_list(spec["categories"]),
             "multiplayer_frequency = %d" % spec["frequency"]]
        if spec["modifiers"]:
            f.append("forced_modifiers = %s" % mm.lua_list(spec["modifiers"]))
        f += ["land_tiles = %d" % land_tiles, "nations = %d" % n]
        if spec.get("world") or spec.get("replicated"):
            f.append("replicated = true")
        lines.append("\t{ %s }," % ", ".join(f))
    lines += ["}", "", "local by_id: { [string]: any } = {}", "for _, m in MapList.maps do", "\tby_id[m.id] = m", "end",
              "", "--- Registry row of map `id` (nil if unknown).",
              '--- (a size suffix — "world@80", see WorldMap.split_id — is ignored)',
              "function MapList.get(id: string): any", '\treturn by_id[string.match(id, "^(.-)@%d+$") or id]', "end",
              "", "return MapList", ""]
    with open(os.path.join(REPO, "src", "shared", "Data", "MapList.luau"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def read_row(spec):
    s = open(module_path(spec), encoding="utf-8").read()
    g = lambda k: int(re.search(r"\b%s = (\d+)" % k, s).group(1))  # noqa: E731
    return spec, g("width"), g("height"), g("land_tiles"), s.count("flag = ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ne", required=True)
    ap.add_argument("--old", required=True)
    ap.add_argument("--only")
    ap.add_argument("--preview")
    ap.add_argument("--patch", action="store_true", help="only rewrite nations and sites of built modules")
    ap.add_argument("--no-registry", action="store_true", help="leave Data/MapList as it is")
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None
    sources = load_sources(a.old)
    rows = []
    for spec in MAPS:
        if a.patch:
            rows.append(patch_sites(spec, a.old))
        elif only is None or spec["id"] in only:
            rows.append(build(spec, a.ne, sources, a.old, a.preview))
        elif not a.no_registry:
            rows.append(read_row(spec))
    if not a.no_registry:
        write_registry(rows)


if __name__ == "__main__":
    sys.setrecursionlimit(10000)
    main()
