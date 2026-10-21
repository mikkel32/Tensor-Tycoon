import Foundation

// MARK: - 3.9: world map geography
//
// Static data for the World Map screen: simplified coastlines (a few hundred points, enough for a dot-matrix map),
// rough outlines of the seven policy regions, and real-world coordinates for every place the catalogues name —
// datacenter locations, headquarters cities, foundries and suppliers, agencies, rival labs and their training sites.
// Coordinates are longitude, latitude in degrees, rounded to about 10 km. Nothing here is saved.

/// A point on Earth: longitude and latitude in degrees.
struct GeoPoint: Hashable, Sendable {
    var lon: Double
    var lat: Double

    init(_ lon: Double, _ lat: Double) {
        self.lon = lon
        self.lat = lat
    }

    /// A point `dLon`/`dLat` degrees away (for plants next to a campus and pins next to each other).
    func offset(_ dLon: Double, _ dLat: Double) -> GeoPoint { GeoPoint(lon + dLon, lat + dLat) }
}

enum WorldMapGeo {
    typealias Ring = [GeoPoint]

    /// The map shows −56° to 78° latitude: everything people live on, without Antarctica's huge smear.
    static let latRange: ClosedRange<Double> = -56...78
    static let lonRange: ClosedRange<Double> = -170...180

    private static func ring(_ pts: [(Double, Double)]) -> Ring { pts.map { GeoPoint($0.0, $0.1) } }

    // MARK: Land

    /// Simplified land outlines. Inland seas are traced as inlets where they're big enough to show at 1.5° (Hudson
    /// Bay, the Baltic, the Black Sea, the Caspian, the Persian Gulf, the Red Sea).
    static let land: [Ring] = [
        // North America
        ring([(-95, 68), (-94, 60), (-92, 57), (-87, 55.5), (-82, 52.5), (-79, 54.5), (-78, 58), (-77.5, 62.3), (-73, 62), (-70, 61), (-65, 60.5),
              (-61, 56), (-56, 52.5), (-59, 48), (-64, 48.5), (-60, 46), (-66, 44.5), (-70, 43.5), (-70, 41.6), (-74, 40.5), (-76, 37),
              (-75.5, 35.2), (-78, 33.8), (-81, 31.5), (-80.5, 28), (-80, 25.3), (-81.5, 25.2), (-82.7, 27.8), (-84, 30), (-87, 30.3),
              (-89.5, 29.2), (-91, 29.5), (-94, 29.6), (-97.3, 27.5), (-97.5, 24), (-97.7, 21.5), (-96, 19), (-94.5, 18.2), (-91, 18.6),
              (-90.5, 21), (-87, 21.5), (-87.5, 18), (-88.3, 15.8), (-84, 15.9), (-83.2, 14.9), (-83.5, 11), (-81.8, 8.9), (-79.5, 9.5),
              (-77.4, 8.6), (-78, 7.2), (-80, 7.4), (-83, 8.3), (-85.8, 10.2), (-87.5, 13), (-91.5, 14), (-94.5, 16), (-97.8, 16),
              (-101, 17.5), (-105.5, 20), (-105.5, 22.8), (-109.4, 23), (-112, 26.5), (-114.5, 29.5), (-117.1, 32.5), (-118.5, 34),
              (-120.6, 34.6), (-122.5, 37.5), (-124, 40.5), (-124.5, 43), (-124, 46.3), (-124.7, 48.4), (-123, 49), (-127.5, 50.8),
              (-130.5, 54.5), (-133, 57), (-137, 58.5), (-140, 59.8), (-146, 60.8), (-151.5, 59.2), (-154, 57.5), (-158, 56.5),
              (-162, 55.2), (-164.5, 54.6), (-158.5, 58.8), (-162, 60), (-165, 62.5), (-161, 64.5), (-166, 65.4), (-168, 65.6),
              (-163, 67), (-166, 68.8), (-162, 70.2), (-156.5, 71.3), (-148, 70.3), (-141, 69.6), (-133, 69.5), (-125, 69.8),
              (-115, 68.8), (-108, 68.3), (-98, 67.8)]),
        // Canadian Arctic islands
        ring([(-123, 76), (-100, 79.5), (-80, 83), (-62, 82.5), (-75, 78), (-85, 76.5), (-95, 74.5), (-105, 72.5), (-118, 70.8), (-125, 71.5)]),
        ring([(-80, 73.5), (-71, 70.5), (-64, 67), (-62, 66.5), (-65, 64), (-71, 62.5), (-78, 64.5), (-74, 66), (-75, 68), (-84, 70), (-90, 72.5), (-85, 73.8)]),
        // Greenland, Iceland
        ring([(-73, 78.5), (-60, 82), (-35, 83.6), (-20, 82), (-12, 81.5), (-18, 77), (-19, 74), (-22, 70.5), (-27, 68.5), (-35, 66), (-40, 65),
              (-43, 60), (-48, 61), (-51, 64), (-54, 67), (-53, 70), (-56, 73), (-60, 76), (-68, 77)]),
        ring([(-24, 65.5), (-22, 66.4), (-16, 66.5), (-13.5, 65.2), (-15, 64.3), (-18.7, 63.4), (-22.5, 63.8)]),
        // Caribbean
        ring([(-85, 21.9), (-82, 23.2), (-77, 22), (-74.1, 20.2), (-77.7, 19.9), (-81, 21.6)]),
        ring([(-74.4, 19.9), (-68.4, 19.0), (-68.5, 18.4), (-71.5, 17.7), (-74.4, 18.3)]),
        // South America
        ring([(-77.4, 8.6), (-75.5, 10.8), (-71.5, 12.4), (-70, 11.5), (-64, 10.6), (-61, 10.7), (-58.5, 7), (-54, 5.8), (-51, 4.2), (-50, 1.8),
              (-48.5, -1), (-44.5, -2.5), (-40, -2.9), (-35.2, -5.4), (-34.8, -7.5), (-37, -11), (-39, -15), (-39.5, -18), (-41, -22),
              (-44, -23), (-48.5, -26), (-48.8, -28.5), (-51, -31), (-53.4, -33.8), (-55, -35), (-57.2, -35.4), (-57, -38), (-62, -39),
              (-65, -41), (-63.8, -42.5), (-65.5, -45), (-67.5, -46.5), (-66, -48), (-69, -51), (-68.5, -52.5), (-70, -54), (-73, -53),
              (-75, -50), (-75.5, -46), (-74, -43), (-73.5, -39.5), (-73.2, -37), (-71.6, -33), (-71.5, -29), (-70.3, -23.5),
              (-70.2, -18.4), (-71.5, -17.5), (-75, -15.3), (-76.3, -13.5), (-78, -10), (-79.8, -7), (-81.2, -5.5), (-80.4, -3.4),
              (-80, -1), (-80.1, 0.9), (-78.9, 1.6), (-77.5, 4), (-77.3, 6.6)]),
        // Europe west of the Urals, with Scandinavia; the Baltic and Black Sea traced as inlets
        ring([(-5.6, 36), (-9, 37), (-8.9, 39.5), (-8.8, 42.1), (-9.2, 43.2), (-7.5, 43.7), (-1.8, 43.4), (-1.2, 46.2), (-2.7, 47.5),
              (-4.7, 48.4), (-1.5, 48.7), (0.2, 49.6), (1.6, 50.9), (3.5, 51.4), (5, 53.3), (8.5, 53.6), (8.6, 55.5), (8.2, 57),
              (10.5, 57.7), (10.3, 56.2), (9.8, 55), (10.9, 54.3), (12.5, 54.4), (14.2, 53.9), (16.5, 54.5), (18.6, 54.4), (19.9, 54.9),
              (21.1, 55.7), (21, 56.8), (21.6, 57.5), (23.4, 57), (24.4, 57.8), (23.5, 58.5), (23.5, 59.3), (28, 59.5), (30, 59.9),
              (27, 60.5), (23, 59.9), (21.4, 60.7), (21.5, 62.8), (25, 65), (24.5, 65.8), (22.3, 65.8), (21.3, 64.4), (19.2, 63.3),
              (17.4, 62.3), (17.2, 61), (18.8, 59.8), (16.5, 57.5), (16, 56.2), (14.3, 55.6), (12.9, 55.4), (12.6, 56.2), (11.6, 58),
              (11.1, 59), (10.2, 59), (8, 58.1), (5.6, 58.7), (5, 60.5), (5, 62), (7, 62.9), (10, 64.3), (12.5, 66), (14.5, 67.8),
              (16, 68.8), (19, 69.9), (23, 70.6), (26, 71), (28.5, 70.9), (31, 70.3), (33, 69.4), (36, 69.1), (41, 67.8), (44, 68.4),
              (47, 67.7), (53, 68.6), (58, 68.6), (60, 69.5), (60, 55), (56, 51), (53, 47), (49.5, 46.6), (47.5, 45.5), (48.5, 42),
              (47.5, 43), (41.5, 41.5), (40, 43.5), (38, 44.8), (36.6, 45.3), (33.5, 44.5), (32.5, 45.4), (30.5, 46.5), (29.6, 45.2),
              (28.6, 44), (28, 42), (29, 41.2), (26.2, 40.6), (24, 40.9), (22.9, 40.5), (23.2, 39.2), (24, 38), (22.9, 36.4), (21.7, 36.8),
              (21.1, 38.3), (20.2, 39.6), (19.4, 41.8), (16, 43.5), (15.2, 44.3), (13.6, 45.7), (12.3, 45.3), (12.5, 44.2), (13.9, 42.5),
              (16.1, 41.4), (18.5, 40.2), (17, 39), (16.6, 38), (15.7, 38), (15.6, 40), (14, 40.8), (12.4, 41.8), (10.5, 43), (9, 44.4),
              (7.5, 43.8), (5, 43.4), (3.2, 43.2), (3.2, 41.9), (1, 41), (0, 39.5), (-0.5, 38.3), (-2, 36.8), (-4.5, 36.6)]),
        // Asia from the Urals, with the Caucasus, Turkey, the Middle East, India, Indochina and Korea
        ring([(60, 69.5), (68, 70.5), (72, 72.8), (76, 72), (80, 73.5), (87, 75), (95, 76), (104, 77.7), (112, 76.5), (120, 73), (130, 71),
              (140, 72.5), (150, 71.5), (160, 70), (170, 70), (180, 68.8), (180, 65), (178, 64.5), (174, 61.8), (170, 60), (163, 59.8),
              (163, 56), (160.5, 54), (156.5, 51), (155.5, 55.5), (156, 57.8), (160, 61), (154, 59.3), (149, 59.4), (143, 59.3), (137, 54),
              (141, 52.2), (140.5, 48.5), (135, 43.5), (132, 43), (129.5, 41), (128.3, 38.6), (129.4, 36), (129.2, 35.2), (126.6, 34.4),
              (126.2, 36.7), (126.7, 37.7), (125.1, 37.9), (124.5, 39.8), (121.5, 39), (121.2, 40.9), (119.5, 39.8), (117.8, 39),
              (118.5, 38), (119.2, 37.1), (122.5, 37.4), (120.3, 36), (119.3, 35), (120.8, 32.6), (121.9, 30.8), (121.5, 28.4),
              (119.6, 25.5), (116.5, 23), (113.5, 22.2), (110.5, 21.2), (110.2, 20.2), (108.5, 21.6), (106.6, 20.2), (105.7, 18.8),
              (106.5, 17.4), (108.8, 15.2), (109.2, 12), (107.3, 10.4), (105, 8.7), (104.8, 10.4), (103.5, 10.6), (102.3, 12.2),
              (100.9, 13.4), (100, 12.5), (99.2, 10), (100.3, 8.4), (101.3, 6.8), (103.4, 4.9), (103.5, 2.5), (104.2, 1.4), (103.4, 1.3),
              (101.3, 2.9), (100.4, 5), (98.3, 8), (98.6, 10), (97.7, 15), (97, 16.9), (94.5, 16), (94.2, 18.8), (92.3, 20.7),
              (91.8, 22.4), (90.5, 22), (88.7, 21.6), (87, 21.3), (86.9, 20.2), (84.8, 19.2), (82.3, 16.6), (80.3, 15.8), (80.2, 13.5),
              (79.8, 10.3), (78, 8.4), (77.5, 8), (76.5, 9), (75.5, 11.8), (74.7, 13.8), (73.3, 17), (72.8, 19.5), (72.8, 21),
              (72.2, 21.9), (70.5, 20.8), (69, 22.4), (68.4, 23.6), (67.4, 24), (66.6, 25.4), (64.5, 25.2), (61.6, 25.2), (58.8, 25.5),
              (57.3, 25.8), (56.4, 27.1), (54.7, 26.5), (51.6, 27.9), (50.2, 30), (48, 30), (48.4, 28.5), (48.9, 27.6), (50.1, 26.2),
              (50.8, 24.8), (51.4, 24.3), (53.8, 24.1), (55.5, 25.4), (56.3, 26.3), (56.4, 24.9), (57.8, 23.7), (59.8, 22.5),
              (58.5, 20.4), (57.7, 19), (56.5, 17.9), (55, 17), (52.2, 15.6), (48.7, 14), (45, 12.8), (43.5, 12.7), (42.7, 15.7),
              (42.5, 17.5), (40.8, 19.8), (39, 21.8), (38.4, 23.7), (37.2, 25), (35.5, 28), (34.9, 29.5), (34.3, 31.2), (34.9, 32.8),
              (35.6, 34.5), (35.9, 36.6), (34.6, 36.8), (32.5, 36.1), (30.6, 36.7), (28, 36.7), (27.3, 37.5), (26.3, 38.5), (26.7, 39.5),
              (26.1, 40.1), (29, 41.2), (31.3, 41.1), (34, 42), (36, 41.7), (38.5, 40.9), (41.5, 41.5), (46.5, 41.8), (49.5, 40.2),
              (48.8, 38.5), (49, 37.5), (51, 36.7), (53.9, 36.9), (53.5, 39.3), (53, 42.1), (51.3, 43.2), (51.5, 45.5), (53, 46.8),
              (53, 47), (56, 51), (60, 55)]),
        // Africa, Madagascar
        ring([(-5.9, 35.8), (-2, 35.1), (1, 36.5), (3.2, 36.8), (8.6, 36.9), (10.2, 37.2), (11, 36.8), (10.2, 35), (10.9, 33.8), (11.5, 33.1),
              (15.3, 32.3), (19, 30.3), (20, 32.2), (22, 32.9), (25, 31.7), (29, 30.9), (32.3, 31.3), (34.2, 31.3), (32.6, 29.9),
              (33.6, 27.5), (35.5, 24), (37.2, 21), (38.5, 18), (39.7, 15.5), (41.7, 13.4), (43.3, 11.8), (44.5, 10.4), (51.2, 11.8),
              (51, 10.4), (49, 6.5), (47.5, 4.5), (44, 1), (41.5, -1.8), (40, -3.5), (39.2, -6.5), (39.6, -10), (40.5, -11), (40.6, -15),
              (36.8, -17.9), (35, -20), (35.5, -23.8), (32.9, -25.9), (32.4, -28.6), (30.9, -30.5), (27.9, -33.4), (25.6, -34),
              (22, -34.2), (20, -34.8), (18.4, -34.1), (17.9, -31.5), (16.5, -28.6), (15.2, -26.6), (14.5, -22.9), (13.4, -20.8),
              (11.8, -17.3), (11.8, -15.8), (12.5, -13.5), (13.7, -11.5), (13.2, -9), (12.2, -6), (11.1, -3.9), (9.3, -1.5), (9.5, 1),
              (9.7, 3.5), (8.8, 4.5), (6.1, 4.3), (4.5, 6.3), (2.5, 6.3), (-1, 5), (-4, 5.2), (-7.5, 4.4), (-9.3, 5.5), (-11.5, 6.9),
              (-13.2, 8.5), (-15, 10.9), (-16.7, 12.4), (-17.5, 14.7), (-16.2, 19), (-16.4, 22), (-15, 24.5), (-13.2, 27), (-10, 29.5),
              (-9.6, 30.4), (-9.6, 32.6), (-6.8, 34)]),
        ring([(49.3, -12), (50.4, -15.5), (49.5, -17), (47.1, -24.9), (45.2, -25.5), (43.7, -23.5), (43.3, -21.5), (44.4, -19.5), (44, -17),
              (46.3, -15.8), (48, -13.5)]),
        // Great Britain, Ireland
        ring([(-5.7, 50), (-3, 50.6), (1.4, 51.2), (1.7, 52.7), (0.2, 53.5), (-0.4, 54.5), (-1.6, 55.6), (-2.1, 57.7), (-3.3, 58.6), (-5, 58.6),
              (-6.2, 57.5), (-5.6, 55.4), (-4.9, 54.8), (-3.3, 54.9), (-3, 53.4), (-4.5, 53.4), (-4.8, 52), (-5.2, 51.7), (-3.4, 51.4),
              (-4.5, 51.2)]),
        ring([(-6, 52.2), (-6.2, 53.3), (-6, 54.6), (-7.3, 55.3), (-8.5, 54.6), (-10, 54.2), (-10, 53.4), (-9.4, 52.5), (-10.3, 51.9), (-8.5, 51.6)]),
        // Japan, Taiwan, Sri Lanka, Sakhalin, the Philippines
        ring([(129.8, 33.2), (131, 31.3), (132, 33.3), (134.7, 33.8), (135.8, 33.5), (137.2, 34.6), (139, 34.9), (140.9, 35.7), (141, 38.3),
              (141.9, 39.5), (141.5, 41.4), (140, 40.9), (139.8, 39.8), (140, 38), (138.5, 37.6), (136.8, 37.3), (136, 35.7), (133, 35.5),
              (131, 34.4)]),
        ring([(140, 41.5), (141.2, 41.8), (143.3, 42), (145.5, 43.3), (144.5, 44), (141.8, 45.4), (141.4, 43.3), (140, 42.5)]),
        ring([(120.1, 23), (121, 22), (121.9, 24.6), (121.5, 25.3), (120.6, 24.6)]),
        ring([(79.9, 9.8), (81.9, 7.5), (81.2, 6.1), (80, 6), (79.8, 8)]),
        ring([(142, 46), (143.5, 49.3), (142.5, 54.3), (142, 51.5)]),
        ring([(120.5, 18.5), (122.3, 18.4), (124.3, 12.6), (126.5, 8), (125.6, 5.7), (122, 6.9), (121.8, 11.8), (120, 14.5)]),
        // Indonesia, New Guinea
        ring([(95.3, 5.6), (97.5, 5.2), (100.4, 2.2), (104.6, -1.9), (106, -3.2), (105.8, -5.8), (104.5, -5.9), (102.3, -4), (100.4, -1),
              (98.6, 1.7), (96, 4.2)]),
        ring([(105.2, -6.8), (106.5, -6), (110.5, -6.9), (114.5, -7.7), (114.4, -8.7), (110, -8.1), (106.4, -7.4)]),
        ring([(109, 1.5), (109.6, -1), (110.2, -2.9), (114.5, -3.5), (116.5, -3), (116, 0.5), (117.8, 1), (118.9, 4.9), (117.2, 6.9), (116, 6),
              (113, 3.2), (111.2, 2.4)]),
        ring([(119.4, -5.5), (120.4, -5.5), (121, -2.8), (120.4, 0.5), (124.9, 1.5), (121.4, -1), (122.8, -4.6), (121.5, -4.6), (119.5, -3.5)]),
        ring([(131, -1.2), (134.2, -0.8), (138, -1.6), (141, -2.6), (145.8, -4.9), (147.6, -6), (147.9, -8), (150, -10.5), (146, -8.1),
              (143.5, -9), (141, -9.1), (138.5, -8.3), (137.8, -5.2), (135.2, -4.4), (132.9, -4), (132, -2.8)]),
        // Australia, Tasmania, New Zealand
        ring([(113.4, -22.0), (114.2, -26.3), (115, -29.5), (115.6, -33.5), (115, -34.3), (117.9, -35.1), (120, -33.9), (123.6, -33.9),
              (126, -32.3), (131.2, -31.5), (134.2, -32.8), (135.9, -34.8), (137.5, -33), (137.8, -35.6), (139.6, -36.2), (140.6, -38),
              (143.5, -38.8), (146.4, -39.1), (148, -37.8), (150, -37.5), (150.8, -34.5), (151.4, -33.5), (153.1, -30.3), (153.6, -28.2),
              (153, -25.5), (150.8, -22.6), (148.8, -20.4), (146.3, -18.9), (145.4, -15.6), (143.6, -14), (142.5, -10.7), (141.6, -12.6),
              (141.6, -15.7), (140.6, -17.6), (139.3, -17.4), (137.9, -16.3), (136, -15.3), (135.9, -13.4), (136.9, -12.3), (136, -11.9),
              (132.6, -11.4), (131, -12.2), (129.4, -14.9), (127.8, -14.2), (125.2, -14.6), (123.5, -17), (122.2, -18.2), (119.1, -19.9),
              (116.8, -20.6), (114.6, -21.8)]),
        ring([(144.6, -40.7), (148.3, -40.9), (148, -43.2), (146, -43.6), (145.2, -42.2)]),
        ring([(172.7, -34.4), (174.6, -36.4), (178.5, -37.7), (177.9, -39.2), (176.9, -39.6), (175.2, -41.6), (174.6, -41.3), (175.1, -39.9),
              (173.8, -39.2), (174.6, -37.5)]),
        ring([(172.7, -40.5), (174.2, -41.7), (173.2, -43), (171.2, -44.4), (169, -46.7), (166.5, -46), (168.4, -44), (171.3, -41.8)]),
    ]

    // MARK: Policy regions

    /// Rough outlines of the seven regions whose rules the game tracks. Only land inside them is tinted, so the
    /// outlines can cut across the sea. Checked in this order (the UK before the EU).
    static let regions: [(region: Region, rings: [Ring])] = [
        (.uk, [ring([(-6, 49.8), (2, 50.8), (2, 53), (-1.3, 55.9), (-1.5, 61), (-7.8, 58.8), (-6.2, 56), (-5.2, 54.5), (-5.8, 53.8)]),
               ring([(-5.4, 54), (-8.2, 54.4), (-7.2, 55.4), (-5.6, 55.2)])]),
        (.eu, [ring([(-10, 36), (-10, 44), (-5, 48.8), (-1, 49.8), (1.5, 51.1), (3, 51.6), (4.5, 53.4), (7, 53.8), (8.3, 55.1), (8, 57.2),
                     (10.6, 57.9), (11.4, 59.1), (12.4, 60.3), (12.1, 61.7), (12.3, 63.2), (14.2, 64.9), (15.9, 66.3), (18, 68.4), (20.5, 69.1),
                     (24, 68.6), (26, 69.9), (28.9, 69), (28.7, 68), (30, 67.5), (29.5, 66), (30.1, 64.7), (31.5, 62.9), (29, 61.2),
                     (27.8, 60.5), (28.1, 59.4), (27.4, 58), (27.7, 57.3), (28.2, 56.2), (26.6, 55.7), (25.7, 54.3), (23.5, 53.9),
                     (23.9, 52.7), (23.6, 51.5), (24.1, 50.8), (22.7, 49.6), (22.9, 48), (24.9, 47.7), (26.6, 48.3), (28, 45.5), (29.7, 45.2),
                     (28.6, 43.7), (28, 42), (26.4, 41.7), (26, 40.6), (28.2, 36.4), (23.5, 35), (21, 36.6), (20, 39.6), (21, 40.8),
                     (22.9, 41.3), (22.4, 42.3), (22.9, 43.2), (22.4, 44.2), (21.4, 44.8), (20.3, 46.1), (19, 45.9), (17.6, 45.9),
                     (16.6, 45.2), (15.8, 44.8), (17.6, 43), (18.5, 42.5), (19, 40), (18.6, 39.8), (16, 37.5), (12, 36.5), (8, 38.8), (8, 41.2),
                     (7.5, 43.7), (3.5, 43), (3.2, 41.5), (-0.5, 38), (-2, 36.5), (-5.6, 35.9)]),
               ring([(-6, 51.5), (-10.7, 51.5), (-10.5, 55.4), (-7.2, 55.4), (-8.2, 54.4), (-6.1, 54), (-5.9, 53)])]),
        (.china, [ring([(73.5, 39.5), (75, 37), (78, 35.5), (79, 32.5), (81, 30.2), (85, 28.3), (88, 27.9), (92, 27.8), (96, 29), (98.5, 27.6),
                        (98, 24), (99.5, 22), (101.5, 21.2), (102, 22.4), (105.5, 23), (106.7, 22), (108, 21.5), (110, 20.2), (113.5, 22.2),
                        (116.5, 23), (119.6, 25.5), (121.5, 28.4), (121.9, 30.8), (120.8, 32.6), (119.3, 35), (120.3, 36), (122.5, 37.4),
                        (119.2, 37.1), (118.5, 38), (117.8, 39), (119.5, 39.8), (121.2, 40.9), (121.5, 39), (124.4, 40), (126, 41.3),
                        (128, 42), (130.6, 42.4), (131.2, 44.9), (134.7, 48.3), (132.5, 47.7), (130.7, 48.9), (127.5, 49.8), (125.5, 53),
                        (120.5, 53.3), (119.7, 50), (116.7, 49.8), (117.8, 48.4), (119.8, 47), (116, 45.5), (112, 45), (111, 43.4),
                        (107, 42.4), (105, 41.7), (100, 42.6), (96.4, 42.7), (95.3, 44.2), (91, 45.5), (90.6, 47.5), (87.8, 49.1), (85.5, 48),
                        (82.6, 47.2), (80.2, 45), (80, 42.9), (76.5, 40.4)])]),
        (.gulf, [ring([(36.5, 29.4), (37, 31.5), (39, 32), (42, 31.1), (44.7, 29.2), (46.5, 29.1), (48, 29.8), (48.4, 28.5), (50.1, 26.2),
                       (51.6, 24.2), (56.4, 26.3), (56.4, 24.9), (59.8, 22.5), (57.7, 19), (55, 17), (52.2, 16.6), (49, 18.6), (46, 17.3),
                       (43.3, 17.5), (42.8, 16.4), (40.8, 19.8), (39, 21.8), (38.4, 23.7), (37.2, 25), (35.5, 28), (34.9, 29.5)])]),
        (.india, [ring([(68.2, 23.7), (71, 24.4), (70.8, 25.8), (69.6, 27.2), (72, 28.7), (74.5, 30.9), (74.6, 32.5), (74, 34.5), (77, 35.5),
                        (78.5, 34), (79.3, 32.5), (78.8, 31.3), (81, 30.2), (83, 27.4), (88.1, 26.5), (88.8, 27.2), (92, 27.8), (96, 29),
                        (97.3, 28), (97, 27.2), (95, 26), (94, 23.9), (93.3, 22), (92.3, 20.7), (88.7, 21.6), (87, 21.3), (84.8, 19.2),
                        (82.3, 16.6), (80.2, 13.5), (79.8, 10.3), (77.5, 8), (75.5, 11.8), (73.3, 17), (72.8, 21), (70.5, 20.8), (69, 22.4)])]),
        (.japanKorea, [ring([(126.1, 34.3), (129.4, 35.2), (129.5, 36.5), (128.4, 38.6), (127.1, 38.3), (126.1, 37.7)]),
                       ring([(129, 31), (132, 33), (135.5, 33), (141, 35.5), (142.5, 40), (146, 43.5), (142, 46), (139.5, 42), (139, 38),
                             (136, 37.5), (130, 34.5)])]),
        (.us, [ring([(-124.7, 48.4), (-123, 49), (-95, 49), (-89, 48), (-84.5, 46.5), (-82.5, 45.3), (-82.4, 43), (-79, 43.3), (-76.5, 44.2),
                     (-74.7, 45), (-71.5, 45), (-69.2, 47.4), (-67.8, 47.1), (-67, 44.8), (-70, 43.5), (-70, 41.6), (-74, 40.5), (-76, 37),
                     (-75.5, 35.2), (-78, 33.8), (-81, 31.5), (-80.5, 28), (-80, 25.3), (-81.5, 25.2), (-82.7, 27.8), (-84, 30), (-87, 30.3),
                     (-89.5, 29.2), (-91, 29.5), (-94, 29.6), (-97.2, 25.9), (-99.5, 27.5), (-101.4, 29.8), (-104.5, 29.6), (-106.5, 31.8),
                     (-108.2, 31.3), (-111, 31.3), (-114.8, 32.5), (-117.1, 32.5), (-118.5, 34), (-120.6, 34.6), (-122.5, 37.5), (-124, 40.5),
                     (-124.5, 43), (-124, 46.3)]),
               ring([(-168, 65.6), (-163, 67), (-166, 68.8), (-156.5, 71.3), (-141, 69.6), (-141, 60), (-146, 60.8), (-151.5, 59.2),
                     (-158, 56.5), (-164.5, 54.6), (-162, 60), (-166, 62)])]),
    ]

    /// Where a region's label and arrows sit.
    static func anchor(_ r: Region) -> GeoPoint {
        switch r {
        case .us: GeoPoint(-98, 39)
        case .eu: GeoPoint(14, 49)
        case .uk: GeoPoint(-3, 54)
        case .china: GeoPoint(104, 34)
        case .gulf: GeoPoint(46, 23)
        case .india: GeoPoint(78.5, 22)
        case .japanKorea: GeoPoint(135, 36.5)
        }
    }

    /// Where a region's AI spending is booked, for the revenue flows: its biggest financial centre.
    static func marketHub(_ r: Region) -> GeoPoint {
        switch r {
        case .us: GeoPoint(-74.0, 40.7)       // New York
        case .eu: GeoPoint(8.68, 50.11)       // Frankfurt
        case .uk: GeoPoint(-0.09, 51.51)      // City of London
        case .china: GeoPoint(121.47, 31.23)  // Shanghai
        case .gulf: GeoPoint(55.27, 25.2)     // Dubai
        case .india: GeoPoint(72.88, 19.07)   // Mumbai
        case .japanKorea: GeoPoint(139.69, 35.69)   // Tokyo
        }
    }

    /// A region's capital, for agencies the catalogue doesn't place.
    static func capital(_ r: Region) -> GeoPoint {
        switch r {
        case .us: GeoPoint(-77.04, 38.9)
        case .eu: GeoPoint(4.35, 50.85)
        case .uk: GeoPoint(-0.13, 51.5)
        case .china: GeoPoint(116.4, 39.9)
        case .gulf: GeoPoint(54.37, 24.45)
        case .india: GeoPoint(77.21, 28.61)
        case .japanKorea: GeoPoint(139.75, 35.68)
        }
    }

    // MARK: Places

    /// Datacenter locations (LocationCatalog IDs).
    static let locations: [String: GeoPoint] = [
        "nova": GeoPoint(-77.49, 39.04), "texas": GeoPoint(-99.73, 32.45), "iowa": GeoPoint(-95.86, 41.26), "oregon": GeoPoint(-121.18, 45.6),
        "arizona": GeoPoint(-112.07, 33.45), "quebec": GeoPoint(-73.57, 45.5), "iceland": GeoPoint(-22.6, 63.95), "uae": GeoPoint(54.37, 24.45),
        "dk_jutland": GeoPoint(9.75, 55.57), "fr_rhone": GeoPoint(4.75, 44.6), "it_milan": GeoPoint(9.19, 45.46), "ro_bucharest": GeoPoint(26.1, 44.43),
    ]

    /// Headquarters and office cities (CountryCatalog city IDs).
    static let cities: [String: GeoPoint] = [
        "sf": GeoPoint(-122.42, 37.77), "bucharest": GeoPoint(26.1, 44.43), "cluj": GeoPoint(23.6, 46.77), "milan": GeoPoint(9.19, 45.46),
        "rome": GeoPoint(12.5, 41.9), "turin": GeoPoint(7.69, 45.07), "paris": GeoPoint(2.35, 48.86), "lyon": GeoPoint(4.84, 45.76),
        "grenoble": GeoPoint(5.72, 45.19), "copenhagen": GeoPoint(12.57, 55.68), "aarhus": GeoPoint(10.2, 56.16), "odense": GeoPoint(10.39, 55.4),
        "aalborg": GeoPoint(9.92, 57.05),
    ]

    /// Cities by name: rival headquarters ("Palo Alto & Tel Aviv" uses the first), and a fallback for catalogue places
    /// added later ("Fredericia, Denmark" → "Fredericia").
    static let namedCities: [String: GeoPoint] = [
        "San Francisco": GeoPoint(-122.42, 37.77), "Mountain View": GeoPoint(-122.08, 37.39), "Menlo Park": GeoPoint(-122.18, 37.45),
        "Palo Alto": GeoPoint(-122.14, 37.44), "Seattle": GeoPoint(-122.33, 47.61), "Austin": GeoPoint(-97.74, 30.27),
        "New York": GeoPoint(-74.0, 40.71), "Boston": GeoPoint(-71.06, 42.36), "Toronto": GeoPoint(-79.38, 43.65),
        "Montréal": GeoPoint(-73.57, 45.5), "Montreal": GeoPoint(-73.57, 45.5), "Vancouver": GeoPoint(-123.12, 49.28),
        "Washington": GeoPoint(-77.04, 38.9), "Chicago": GeoPoint(-87.63, 41.88), "Dallas": GeoPoint(-96.8, 32.78),
        "Atlanta": GeoPoint(-84.39, 33.75), "Memphis": GeoPoint(-90.05, 35.15), "Columbus": GeoPoint(-82.99, 39.96),
        "Reno": GeoPoint(-119.81, 39.53), "Salt Lake City": GeoPoint(-111.89, 40.76), "Las Vegas": GeoPoint(-115.14, 36.17),
        "Phoenix": GeoPoint(-112.07, 33.45), "Abilene": GeoPoint(-99.73, 32.45), "Ashburn": GeoPoint(-77.49, 39.04),
        "Council Bluffs": GeoPoint(-95.86, 41.26), "The Dalles": GeoPoint(-121.18, 45.6), "Mexico City": GeoPoint(-99.13, 19.43),
        "São Paulo": GeoPoint(-46.63, -23.55), "Santiago": GeoPoint(-70.67, -33.45),
        "London": GeoPoint(-0.13, 51.51), "Dublin": GeoPoint(-6.26, 53.35), "Paris": GeoPoint(2.35, 48.86), "Berlin": GeoPoint(13.4, 52.52),
        "Munich": GeoPoint(11.58, 48.14), "Frankfurt": GeoPoint(8.68, 50.11), "Amsterdam": GeoPoint(4.9, 52.37), "Brussels": GeoPoint(4.35, 50.85),
        "Zurich": GeoPoint(8.54, 47.38), "Madrid": GeoPoint(-3.7, 40.42), "Lisbon": GeoPoint(-9.14, 38.72), "Milan": GeoPoint(9.19, 45.46),
        "Rome": GeoPoint(12.5, 41.9), "Turin": GeoPoint(7.69, 45.07), "Warsaw": GeoPoint(21.01, 52.23), "Prague": GeoPoint(14.42, 50.08),
        "Vienna": GeoPoint(16.37, 48.21), "Stockholm": GeoPoint(18.07, 59.33), "Luleå": GeoPoint(22.15, 65.58), "Oslo": GeoPoint(10.75, 59.91),
        "Helsinki": GeoPoint(24.94, 60.17), "Copenhagen": GeoPoint(12.57, 55.68), "Fredericia": GeoPoint(9.75, 55.57),
        "Bucharest": GeoPoint(26.1, 44.43), "Reykjanes": GeoPoint(-22.6, 63.95), "Reykjavík": GeoPoint(-21.94, 64.15),
        "Tel Aviv": GeoPoint(34.78, 32.08), "Abu Dhabi": GeoPoint(54.37, 24.45), "Dubai": GeoPoint(55.27, 25.2), "Riyadh": GeoPoint(46.68, 24.71),
        "Doha": GeoPoint(51.53, 25.29), "Bengaluru": GeoPoint(77.59, 12.97), "Hyderabad": GeoPoint(78.49, 17.39), "Mumbai": GeoPoint(72.88, 19.07),
        "Chennai": GeoPoint(80.27, 13.08), "New Delhi": GeoPoint(77.21, 28.61), "Singapore": GeoPoint(103.82, 1.35), "Johor": GeoPoint(103.76, 1.49),
        "Tokyo": GeoPoint(139.69, 35.69), "Osaka": GeoPoint(135.5, 34.69), "Seoul": GeoPoint(126.98, 37.57), "Beijing": GeoPoint(116.4, 39.9),
        "Shanghai": GeoPoint(121.47, 31.23), "Hangzhou": GeoPoint(120.16, 30.27), "Shenzhen": GeoPoint(114.06, 22.54),
        "Hong Kong": GeoPoint(114.17, 22.32), "Taipei": GeoPoint(121.56, 25.03), "Sydney": GeoPoint(151.21, -33.87),
        "Melbourne": GeoPoint(144.96, -37.81),
    ]

    /// Rival training sites, by a word in the rumour mill's description ("its Abilene, Texas campus"). The first match
    /// wins, so specific places come before states.
    static let trainingSites: [(word: String, point: GeoPoint)] = [
        ("Abilene", GeoPoint(-99.73, 32.45)), ("Memphis", GeoPoint(-90.05, 35.15)), ("Mississippi", GeoPoint(-89.98, 34.95)),
        ("Council Bluffs", GeoPoint(-95.86, 41.26)), ("Ohio", GeoPoint(-82.8, 40.08)), ("Wisconsin", GeoPoint(-87.9, 42.7)),
        ("New Mexico", GeoPoint(-106.6, 31.8)), ("Oklahoma", GeoPoint(-95.3, 36.3)), ("Indiana", GeoPoint(-86.5, 41.7)),
        ("Louisiana", GeoPoint(-91.7, 32.4)), ("Texas", GeoPoint(-97.3, 32.75)), ("Hangzhou", GeoPoint(120.16, 30.27)),
        ("Guizhou", GeoPoint(106.63, 26.65)), ("Malaysia", GeoPoint(103.76, 1.49)), ("Johor", GeoPoint(103.76, 1.49)),
        ("Paris", GeoPoint(2.2, 48.7)), ("France", GeoPoint(4.8, 45.3)), ("Nordics", GeoPoint(18.07, 59.33)), ("Tel Aviv", GeoPoint(34.78, 32.08)),
        ("Abu Dhabi", GeoPoint(54.6, 24.3)), ("Riyadh", GeoPoint(46.68, 24.71)), ("Hyderabad", GeoPoint(78.49, 17.39)),
        ("Hokkaido", GeoPoint(141.35, 43.06)), ("Gwangju", GeoPoint(126.85, 35.16)), ("Québec", GeoPoint(-71.2, 46.8)),
    ]

    /// Foundries, packaging and HBM suppliers, and fab sites (SemiCatalog IDs).
    static let semi: [String: GeoPoint] = [
        "fsw": GeoPoint(120.97, 24.8), "hanseong": GeoPoint(127.11, 36.99), "columbia": GeoPoint(-112.15, 33.78), "pearl": GeoPoint(121.6, 31.2),
        "fsw_pack": GeoPoint(120.87, 24.69), "pacific_pack": GeoPoint(120.31, 22.63), "columbia_pack": GeoPoint(-112.24, 33.58),
        "hanseong_mem": GeoPoint(127.0, 37.2), "kumgang_mem": GeoPoint(127.44, 37.27), "snake_mem": GeoPoint(-116.2, 43.62),
        "phoenix": GeoPoint(-112.07, 33.45), "ohio": GeoPoint(-82.8, 40.08), "dresden": GeoPoint(13.74, 51.05), "kumamoto": GeoPoint(130.71, 32.88),
        "tainan": GeoPoint(120.27, 23.1), "pyeongtaek": GeoPoint(127.11, 36.99),
    ]

    /// Agencies that buy advanced programmes (AgencyCatalog IDs).
    static let agencies: [String: GeoPoint] = [
        "oadr": GeoPoint(-77.1, 38.88), "iaro": GeoPoint(-76.94, 38.99), "ncra": GeoPoint(-77.03, 38.9), "feso": GeoPoint(-77.03, 38.89),
        "meridian": GeoPoint(-106.3, 35.88), "naoa": GeoPoint(-77.02, 38.88), "nhri": GeoPoint(-77.1, 39.0), "efrc": GeoPoint(4.35, 50.85),
        "edif": GeoPoint(4.38, 50.84), "ukaia": GeoPoint(-0.13, 51.51), "fsi": GeoPoint(-0.12, 51.5), "gsta": GeoPoint(54.37, 24.45),
        "paia": GeoPoint(139.69, 35.69), "ndma": GeoPoint(77.21, 28.61), "ceri": GeoPoint(4.36, 50.85), "esca": GeoPoint(14.42, 50.08),
        "dgpa": GeoPoint(2.28, 48.83), "cneo": GeoPoint(1.44, 43.6), "cra": GeoPoint(2.17, 48.71), "aoi": GeoPoint(12.5, 41.9),
        "cnci": GeoPoint(7.69, 45.07), "dfgi": GeoPoint(12.57, 55.68), "ansd": GeoPoint(26.1, 44.43),
    ]

    /// Headquarters countries' capitals (CountryCatalog IDs), for national agencies the table above doesn't place.
    static let countryCapitals: [String: GeoPoint] = [
        "us": GeoPoint(-77.04, 38.9), "fr": GeoPoint(2.35, 48.86), "it": GeoPoint(12.5, 41.9), "ro": GeoPoint(26.1, 44.43), "dk": GeoPoint(12.57, 55.68),
    ]

    /// A city by name, trying "A & B" → A and "Town, Region" → Town.
    static func named(_ name: String) -> GeoPoint? {
        if let p = namedCities[name] { return p }
        let first = name.components(separatedBy: " & ").first ?? name
        if let p = namedCities[first] { return p }
        let town = first.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? first
        return namedCities[town]
    }

    /// Where a datacenter location is: the table, else its name.
    static func location(_ id: String) -> GeoPoint? {
        locations[id] ?? LocationCatalog.byID[id].flatMap { named($0.name) }
    }

    /// Where a rival trains, from the rumour mill's words for it (nil when it doesn't say: "rented TPU capacity").
    static func trainingSite(_ text: String) -> GeoPoint? {
        trainingSites.first { text.localizedCaseInsensitiveContains($0.word) }?.point
    }

    /// The continent a point is on, for footprint milestones. Coarse boxes are enough for the places the game has.
    static func continent(_ p: GeoPoint) -> String {
        switch (p.lon, p.lat) {
        case (..<(-30), 12...): "North America"
        case (..<(-30), _): "South America"
        case (-30..<60, 36...): "Europe"
        case (-30..<34, _): "Africa"
        case (34..<60, 12...): "the Middle East"
        case (34..<60, _): "Africa"
        case (110..., ..<(-10)): "Oceania"
        default: "Asia"
        }
    }

    // MARK: Dot matrix

    /// One dot of the map: where it is and which policy region (index into `Region.allCases`, −1 none) it's in.
    struct Dot: Sendable {
        let point: GeoPoint
        let region: Int8
    }

    /// The land as a grid of dots every 1.5°, computed once.
    static let dotStep = 1.5
    static let dots: [Dot] = {
        let landBoxes = land.map(box)
        let regionBoxes = regions.map { ($0.region.index, $0.rings.map { ($0, box($0)) }) }
        var out: [Dot] = []
        out.reserveCapacity(7_000)
        var lat = latRange.lowerBound + dotStep / 2
        while lat < latRange.upperBound {
            var lon = lonRange.lowerBound + dotStep / 2
            while lon < lonRange.upperBound {
                let p = GeoPoint(lon, lat)
                if zip(land, landBoxes).contains(where: { inBox(p, $0.1) && contains($0.0, p) }) {
                    var r: Int8 = -1
                    for (index, rings) in regionBoxes where rings.contains(where: { inBox(p, $0.1) && contains($0.0, p) }) {
                        r = Int8(index)
                        break
                    }
                    out.append(Dot(point: p, region: r))
                }
                lon += dotStep
            }
            lat += dotStep
        }
        return out
    }()

    private static func box(_ r: Ring) -> (minLon: Double, maxLon: Double, minLat: Double, maxLat: Double) {
        (r.map(\.lon).min() ?? 0, r.map(\.lon).max() ?? 0, r.map(\.lat).min() ?? 0, r.map(\.lat).max() ?? 0)
    }

    private static func inBox(_ p: GeoPoint, _ b: (minLon: Double, maxLon: Double, minLat: Double, maxLat: Double)) -> Bool {
        p.lon >= b.minLon && p.lon <= b.maxLon && p.lat >= b.minLat && p.lat <= b.maxLat
    }

    /// Even-odd point-in-polygon test.
    static func contains(_ ring: Ring, _ p: GeoPoint) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in ring.indices {
            let a = ring[i], b = ring[j]
            if (a.lat > p.lat) != (b.lat > p.lat), p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
