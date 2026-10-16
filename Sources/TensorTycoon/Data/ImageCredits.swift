// Generated from the Wikimedia Commons API. All images are freely licensed;
// see each file page for full license terms.

struct ImageCredit: Identifiable, Sendable {
    let id: String
    let title: String
    let author: String
    let license: String
    let page: String
}

enum ImageCredits {
    static let all: [ImageCredit] = [
        ImageCredit(id: "rtx_3090", title: "Size comparison between RTX 3090 and RTX 4090.jpg", author: "Benlisquare", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Size_comparison_between_RTX_3090_and_RTX_4090.jpg"),
        ImageCredit(id: "rtx_4090", title: "Asus Strix RTX 4090.jpg", author: "Benlisquare", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Asus_Strix_RTX_4090.jpg"),
        ImageCredit(id: "rtx_5090", title: "Palit GeForce RTX 5090 Gamerock 20250530 HOF4166 RAW-Export.png", author: "PantheraLeo1359531", license: "CC BY 4.0", page: "https://commons.wikimedia.org/wiki/File:Palit_GeForce_RTX_5090_Gamerock_20250530_HOF4166_RAW-Export.png"),
        ImageCredit(id: "mac_studio", title: "Mac Studio (2022) front.jpg", author: "Yasu (talk)", license: "CC BY-SA 3.0", page: "https://commons.wikimedia.org/wiki/File:Mac_Studio_(2022)_front.jpg"),
        ImageCredit(id: "dgx_spark", title: "Nvidia DGX Spark oblique view dllu.jpg", author: "Daniel Lu (User:dllu)", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Nvidia_DGX_Spark_oblique_view_dllu.jpg"),
        ImageCredit(id: "tesla_p40", title: "Nvidia P40 with Heatsink Removed.jpg", author: "Tim Sheerman-Chase", license: "CC BY 4.0", page: "https://commons.wikimedia.org/wiki/File:Nvidia_P40_with_Heatsink_Removed.jpg"),
        ImageCredit(id: "p100_die", title: "Nvidia@16nm@Pascal@GP100@Tesla P100@T Taiwan 1912A1 PN9G70.S6W GP100-897-A1 DSC07797-DSC07839.jpg", author: "Fritzchens Fritz", license: "CC0", page: "https://commons.wikimedia.org/wiki/File:Nvidia@16nm@Pascal@GP100@Tesla_P100@T_Taiwan_1912A1_PN9G70.S6W_GP100-897-A1_DSC07797-DSC07839.jpg"),
        ImageCredit(id: "a100", title: "Nvidia Tesla A100.png", author: "Nvidia", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Nvidia_Tesla_A100.png"),
        ImageCredit(id: "h100_cards", title: "NVIDIA H100 (极客湾Geekerwan) 004.png", author: "极客湾Geekerwan", license: "CC BY 3.0", page: "https://commons.wikimedia.org/wiki/File:NVIDIA_H100_(%E6%9E%81%E5%AE%A2%E6%B9%BEGeekerwan)_004.png"),
        ImageCredit(id: "h100_stack", title: "NVIDIA H100 (极客湾Geekerwan) 024.png", author: "极客湾Geekerwan", license: "CC BY 3.0", page: "https://commons.wikimedia.org/wiki/File:NVIDIA_H100_(%E6%9E%81%E5%AE%A2%E6%B9%BEGeekerwan)_024.png"),
        ImageCredit(id: "b200_rack", title: "Grafica Nvidia B200.jpg", author: "Javils00", license: "CC0", page: "https://commons.wikimedia.org/wiki/File:Grafica_Nvidia_B200.jpg"),
        ImageCredit(id: "hgx_b200", title: "Nvidia DGX-B200-HGX.jpg", author: "Pokiiri", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Nvidia_DGX-B200-HGX.jpg"),
        ImageCredit(id: "gb200_rack", title: "Nvidia DGX GB200.jpg", author: "Pokiiri", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Nvidia_DGX_GB200.jpg"),
        ImageCredit(id: "tpu_v3", title: "Tensor Processing Unit 3.0.jpg", author: "Zinskauf", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Tensor_Processing_Unit_3.0.jpg"),
        ImageCredit(id: "tpu_v4", title: "TPU v4 (cropped).png", author: "Norman P. Jouppi, George Kurian, Sheng Li, Peter Ma, Rahul Nagarajan, Lifeng Nai, Nishant Patil, Suvinay  Subramanian, Andy Swing, Brian Towles, Cliff Young, Xiang Zhou, Zongwei Zhou, and David Patterson", license: "CC BY 4.0", page: "https://commons.wikimedia.org/wiki/File:TPU_v4_(cropped).png"),
        ImageCredit(id: "amd_instinct", title: "超级核显来袭！AMD新品现场体验 (2160p 60fps VP9-128kbit AAC)-00.06.51.561.png", author: "极客湾Geekerwan", license: "CC BY 3.0", page: "https://commons.wikimedia.org/wiki/File:%E8%B6%85%E7%BA%A7%E6%A0%B8%E6%98%BE%E6%9D%A5%E8%A2%AD%EF%BC%81AMD%E6%96%B0%E5%93%81%E7%8E%B0%E5%9C%BA%E4%BD%93%E9%AA%8C_(2160p_60fps_VP9-128kbit_AAC)-00.06.51.561.png"),
        ImageCredit(id: "amd_racks", title: "超级核显来袭！AMD新品现场体验 (2160p 60fps VP9-128kbit AAC)-00.06.31.698.png", author: "极客湾Geekerwan", license: "CC BY 3.0", page: "https://commons.wikimedia.org/wiki/File:%E8%B6%85%E7%BA%A7%E6%A0%B8%E6%98%BE%E6%9D%A5%E8%A2%AD%EF%BC%81AMD%E6%96%B0%E5%93%81%E7%8E%B0%E5%9C%BA%E4%BD%93%E9%AA%8C_(2160p_60fps_VP9-128kbit_AAC)-00.06.31.698.png"),
        ImageCredit(id: "groq_lpu", title: "LPU-v1-die.jpg", author: "Avivweinstein", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:LPU-v1-die.jpg"),
        ImageCredit(id: "dojo_tile", title: "Tesla Dojo supercomputer tile.jpg", author: "Steve Jurvetson", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:Tesla_Dojo_supercomputer_tile.jpg"),
        ImageCredit(id: "wafer", title: "12-inch silicon wafer.jpg", author: "Peellden", license: "CC BY-SA 3.0", page: "https://commons.wikimedia.org/wiki/File:12-inch_silicon_wafer.jpg"),
        ImageCredit(id: "wafer_closeup", title: "5C2A5953R - 49913961083 – Silicon Wafer 20200519.jpg", author: "Rob Bulmahn", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:5C2A5953R_-_49913961083_%E2%80%93_Silicon_Wafer_20200519.jpg"),
        ImageCredit(id: "garage", title: "BMW Startup Garage Office 1.jpg", author: "Marvel44", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:BMW_Startup_Garage_Office_1.jpg"),
        ImageCredit(id: "server_room", title: "Server Room (22397102849).jpg", author: "Carl Lender from Sunrise, USA", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:Server_Room_(22397102849).jpg"),
        ImageCredit(id: "dc_rows", title: "Datacenter Server Racks (22370909788).jpg", author: "Carl Lender from Sunrise, USA", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:Datacenter_Server_Racks_(22370909788).jpg"),
        ImageCredit(id: "dc_corridor", title: "Racks Amravati Data Center.jpg", author: "PiDatacenters", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Racks_Amravati_Data_Center.jpg"),
        ImageCredit(id: "dc_hall", title: "Datacenter de ARSAT.jpg", author: "IMarcoHerrera", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Datacenter_de_ARSAT.jpg"),
        ImageCredit(id: "rack_rear", title: "Rear of rack at NERSC data center - closeup.jpg", author: "Derrick Coetzee from Berkeley, CA, USA", license: "CC0", page: "https://commons.wikimedia.org/wiki/File:Rear_of_rack_at_NERSC_data_center_-_closeup.jpg"),
        ImageCredit(id: "gpu_cluster", title: "CSIRO ScienceImage 11313 The CSIRO GPU cluster at the data centre.jpg", author: "division, CSIRO", license: "CC BY 3.0", page: "https://commons.wikimedia.org/wiki/File:CSIRO_ScienceImage_11313_The_CSIRO_GPU_cluster_at_the_data_centre.jpg"),
        ImageCredit(id: "supercomputer", title: "Sierra Supercomputer (48002385338).jpg", author: "U.S. Department of Energy from United States", license: "Public domain", page: "https://commons.wikimedia.org/wiki/File:Sierra_Supercomputer_(48002385338).jpg"),
        ImageCredit(id: "hyperscale_campus", title: "Google Data Center, Council Bluffs Iowa (49062863796).jpg", author: "Chad Davis", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:Google_Data_Center,_Council_Bluffs_Iowa_(49062863796).jpg"),
        ImageCredit(id: "dc_construction", title: "Wenatchee washington azure datacenter aerial 1.jpg", author: "Tedder", license: "CC BY 4.0", page: "https://commons.wikimedia.org/wiki/File:Wenatchee_washington_azure_datacenter_aerial_1.jpg"),
        ImageCredit(id: "network", title: "DE-CIX GERMANY - Switch Rack (6218137120).jpg", author: "Stefan Funke from Frankfurt, Germany", license: "CC BY-SA 2.0", page: "https://commons.wikimedia.org/wiki/File:DE-CIX_GERMANY_-_Switch_Rack_(6218137120).jpg"),
        ImageCredit(id: "fiber", title: "Optic fiber cables 01.jpg", author: "SwarmCheng", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Optic_fiber_cables_01.jpg"),
        ImageCredit(id: "immersion", title: "Submer Immersion Cooling SmartPodX.jpg", author: "Submer Immersion Cooling", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Submer_Immersion_Cooling_SmartPodX.jpg"),
        ImageCredit(id: "chiller", title: "Air Cooled Liquid Chiller.jpg", author: "Saud", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Air_Cooled_Liquid_Chiller.jpg"),
        ImageCredit(id: "substation", title: "Muurame electrical substation transformer.jpg", author: "Antti Leppänen", license: "CC BY 4.0", page: "https://commons.wikimedia.org/wiki/File:Muurame_electrical_substation_transformer.jpg"),
        ImageCredit(id: "solar_farm", title: "Solar farm at Krishnapuram Tatipudi Water Works aerial view 01.jpg", author: "Saiphani02", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Solar_farm_at_Krishnapuram_Tatipudi_Water_Works_aerial_view_01.jpg"),
        ImageCredit(id: "nuclear", title: "Cooling tower of the Gösgen Nuclear Power Plant, close view, Däniken, Solothurn.jpg", author: "Christian David", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Cooling_tower_of_the_G%C3%B6sgen_Nuclear_Power_Plant,_close_view,_D%C3%A4niken,_Solothurn.jpg"),
        ImageCredit(id: "generator", title: "Server room backup power generator - IMG 0451.jpg", author: "Jemimus", license: "CC BY 2.0", page: "https://commons.wikimedia.org/wiki/File:Server_room_backup_power_generator_-_IMG_0451.jpg"),
        ImageCredit(id: "stock_exchange", title: "Frankfurt Stock Exchange (Ank Kumar) 03.jpg", author: "Ank Kumar", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Frankfurt_Stock_Exchange_(Ank_Kumar)_03.jpg"),
        ImageCredit(id: "sf_skyline", title: "Golden Gate Bridge and San Francisco skyline from Hawk Hill at Blue Hour dllu.jpg", author: "Daniel L. Lu (user:dllu)", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:Golden_Gate_Bridge_and_San_Francisco_skyline_from_Hawk_Hill_at_Blue_Hour_dllu.jpg"),
        ImageCredit(id: "nvidia_hq", title: "NVIDIA Headquarters.jpg", author: "Coolcaesar", license: "CC BY-SA 4.0", page: "https://commons.wikimedia.org/wiki/File:NVIDIA_Headquarters.jpg"),
    ]
}
