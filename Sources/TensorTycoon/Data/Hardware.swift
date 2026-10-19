import Foundation

enum Vendor: String, Codable, CaseIterable, Sendable, Identifiable {
    case nvidia = "NVIDIA"
    case google = "Google"
    case amd = "AMD"
    case intel = "Intel"
    case aws = "AWS"
    case microsoft = "Microsoft"
    case apple = "Apple"
    case cerebras = "Cerebras"
    case groq = "Groq"
    case tesla = "Tesla"
    case huawei = "Huawei"
    case qualcomm = "Qualcomm"
    case tenstorrent = "Tenstorrent"
    case custom = "Your Silicon"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .nvidia: "cpu.fill"
        case .google: "square.grid.3x3.fill"
        case .amd: "memorychip.fill"
        case .intel: "cpu"
        case .aws: "cloud.fill"
        case .microsoft: "square.split.2x2.fill"
        case .apple: "apple.logo"
        case .cerebras: "circle.hexagongrid.fill"
        case .groq: "bolt.horizontal.fill"
        case .tesla: "bolt.car.fill"
        case .huawei: "antenna.radiowaves.left.and.right"
        case .qualcomm: "dot.radiowaves.left.and.right"
        case .tenstorrent: "circle.grid.cross.fill"
        case .custom: "sparkles"
        }
    }
}

enum AccelClass: String, Codable, CaseIterable, Sendable, Identifiable {
    case consumer = "Consumer"
    case workstation = "Workstation"
    case datacenter = "Datacenter GPU"
    case tpu = "TPU"
    case custom = "Custom ASIC"
    case wafer = "Wafer / SRAM"
    var id: String { rawValue }
}

enum Precision: String, Codable, CaseIterable, Sendable, Identifiable {
    case bf16, fp8, fp4
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bf16: "BF16"
        case .fp8: "FP8 / INT8"
        case .fp4: "FP4"
        }
    }
    var short: String {
        switch self {
        case .bf16: "BF16"
        case .fp8: "FP8"
        case .fp4: "FP4"
        }
    }
    var bytesPerParam: Double {
        switch self {
        case .bf16: 2
        case .fp8: 1
        case .fp4: 0.5
        }
    }
}

/// A real-world AI accelerator. Compute numbers are DENSE (non-sparse) peak TFLOPS.
/// Fields listed in `estimates` are game estimates where the vendor hasn't published a figure.
struct Accelerator: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let vendor: Vendor
    let cls: AccelClass
    let architecture: String
    let announced: YM
    let available: YM
    let discontinued: YM?
    let process: String
    let memoryGB: Double
    let memoryType: String
    let bandwidthTBs: Double
    let bf16: Double
    let fp8: Double
    let fp4: Double
    let int8: Double
    let tdpW: Double
    let interconnect: String
    let interconnectGBs: Double
    let scaleUp: Int
    let price: Double?
    let rent: Double?
    let rentFloor: Double
    let liquid: Bool
    let transistorsB: Double?
    let image: String
    let representativeImage: Bool
    let fact: String
    let estimates: String
    let decodeEff: Double
    let trainFP4Factor: Double
    let weightStreaming: Bool
    let baseMFU: Double
    let minOrder: Int

    static func == (a: Accelerator, b: Accelerator) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var purchasable: Bool { price != nil }
    var rentable: Bool { rent != nil }

    /// Peak dense TFLOPS for training at a precision (falls back if unsupported).
    func trainTFLOPS(_ p: Precision) -> Double {
        switch p {
        case .bf16: return bf16
        case .fp8: return fp8 > 0 ? fp8 : bf16
        case .fp4:
            if fp4 > 0 { return fp4 * trainFP4Factor }
            return fp8 > 0 ? fp8 : bf16
        }
    }

    /// Peak dense TFLOPS (or TOPS) for inference at a serving precision.
    func inferTFLOPS(_ p: Precision) -> Double {
        switch p {
        case .bf16: return bf16
        case .fp8: return max(fp8, int8, bf16)
        case .fp4: return fp4 > 0 ? fp4 : max(fp8, int8, bf16)
        }
    }

    func supportsTraining(_ p: Precision) -> Bool {
        switch p {
        case .bf16: true
        case .fp8: fp8 > 0
        case .fp4: fp4 > 0
        }
    }

    var best: Double { max(bf16, fp8, fp4, int8) }
    var bestPrecisionLabel: String {
        if fp4 > 0 { return "FP4" }
        if fp8 > 0 { return "FP8" }
        if int8 > 0 { return "INT8" }
        return "BF16"
    }

    var cloudProvider: String {
        switch vendor {
        case .google: "Google Cloud"
        case .aws: "AWS"
        case .microsoft: "Azure"
        case .cerebras: "Cerebras Cloud"
        case .groq: "GroqCloud"
        case .huawei: "Huawei Cloud"
        default: cls == .consumer ? "GPU marketplace" : "Neocloud / hyperscaler"
        }
    }

    func isEstimated(_ field: String) -> Bool {
        estimates.lowercased().contains(field.lowercased())
    }
}

private func acc(
    _ id: String, _ name: String, _ vendor: Vendor, _ cls: AccelClass, arch: String,
    announced: YM, available: YM, discontinued: YM? = nil, process: String,
    mem: Double, memType: String, bw: Double,
    bf16: Double, fp8: Double = 0, fp4: Double = 0, int8: Double = 0,
    tdp: Double, ic: String, icGBs: Double, scaleUp: Int,
    price: Double?, rent: Double?, rentFloor: Double = 0,
    liquid: Bool = false, transistors: Double? = nil,
    image: String, rep: Bool = false, fact: String, est: String = "",
    decodeEff: Double = 0.65, trainFP4: Double = 1, streaming: Bool = false, mfu: Double? = nil, minOrder: Int = 1
) -> Accelerator {
    let defaultMFU: Double
    switch cls {
    case .consumer: defaultMFU = 0.33
    case .workstation: defaultMFU = 0.33
    case .datacenter: defaultMFU = 0.40
    case .tpu: defaultMFU = 0.42
    case .custom: defaultMFU = 0.37
    case .wafer: defaultMFU = 0.36
    }
    return Accelerator(
        id: id, name: name, vendor: vendor, cls: cls, architecture: arch,
        announced: announced, available: available, discontinued: discontinued, process: process,
        memoryGB: mem, memoryType: memType, bandwidthTBs: bw,
        bf16: bf16, fp8: fp8, fp4: fp4, int8: int8, tdpW: tdp,
        interconnect: ic, interconnectGBs: icGBs, scaleUp: scaleUp,
        price: price, rent: rent, rentFloor: rentFloor > 0 ? rentFloor : (rent ?? 0) * 0.3,
        liquid: liquid, transistorsB: transistors, image: image, representativeImage: rep,
        fact: fact, estimates: est, decodeEff: decodeEff, trainFP4Factor: trainFP4,
        weightStreaming: streaming, baseMFU: (mfu ?? defaultMFU) * 0.85, minOrder: minOrder)
}

enum HardwareCatalog {
    static let all: [Accelerator] = [
        // MARK: - NVIDIA legacy datacenter
        acc("k80", "Tesla K80", .nvidia, .datacenter, arch: "Kepler (2x GK210)",
            announced: YM(2014, 11), available: YM(2014, 11), discontinued: YM(2018, 6), process: "TSMC 28nm",
            mem: 24, memType: "GDDR5", bw: 0.48, bf16: 8.7,
            tdp: 300, ic: "PCIe 3.0", icGBs: 16, scaleUp: 1,
            price: 5_000, rent: 0.90, rentFloor: 0.20, transistors: 14.2,
            image: "tesla_p40", rep: true, fact: "Two Kepler GPUs on one board and the free GPU in early Google Colab. FP32 only, no tensor cores.",
            est: "rent", mfu: 0.28),
        acc("t4", "Tesla T4", .nvidia, .datacenter, arch: "Turing",
            announced: YM(2018, 9), available: YM(2018, 10), process: "TSMC 12nm FFN",
            mem: 16, memType: "GDDR6", bw: 0.32, bf16: 65, int8: 130,
            tdp: 70, ic: "PCIe 3.0", icGBs: 16, scaleUp: 1,
            price: 2_300, rent: 0.35, rentFloor: 0.11, transistors: 13.6,
            image: "tesla_p40", rep: true, fact: "70 W, single slot, everywhere: the default cloud inference GPU of 2019–2022. FP16 tensor cores, no BF16.",
            est: "price"),
        acc("p40", "Tesla P40", .nvidia, .datacenter, arch: "Pascal",
            announced: YM(2016, 9), available: YM(2016, 10), discontinued: YM(2021, 6), process: "TSMC 16nm",
            mem: 24, memType: "GDDR5", bw: 0.346, bf16: 11.8, int8: 47,
            tdp: 250, ic: "PCIe 3.0", icGBs: 16, scaleUp: 1,
            price: 5_700, rent: 0.90, rentFloor: 0.12, transistors: 12,
            image: "tesla_p40", fact: "No tensor cores: trains in FP32 only, but 24 GB was huge for 2016 inference.",
            est: "rent", mfu: 0.30),
        acc("p100", "Tesla P100 SXM2", .nvidia, .datacenter, arch: "Pascal",
            announced: YM(2016, 4), available: YM(2016, 9), discontinued: YM(2021, 1), process: "TSMC 16nm",
            mem: 16, memType: "HBM2", bw: 0.732, bf16: 21.2,
            tdp: 300, ic: "NVLink 1.0", icGBs: 160, scaleUp: 8,
            price: 9_400, rent: 1.46, rentFloor: 0.30, transistors: 15.3,
            image: "p100_die", fact: "First GPU with HBM2 and NVLink — the engine of DGX-1.",
            est: "price", mfu: 0.30),
        acc("v100_16", "Tesla V100 SXM2 16GB", .nvidia, .datacenter, arch: "Volta",
            announced: YM(2017, 5), available: YM(2017, 7), discontinued: YM(2022, 1), process: "TSMC 12nm FFN",
            mem: 16, memType: "HBM2", bw: 0.9, bf16: 125,
            tdp: 300, ic: "NVLink 2.0", icGBs: 300, scaleUp: 8,
            price: 9_000, rent: 3.06, rentFloor: 0.45, transistors: 21.1,
            image: "p100_die", rep: true, fact: "Introduced Tensor Cores: 125 TFLOPS of FP16 matrix math.",
            est: "price"),
        acc("titan_v", "TITAN V", .nvidia, .consumer, arch: "Volta",
            announced: YM(2017, 12), available: YM(2017, 12), discontinued: YM(2019, 6), process: "TSMC 12nm FFN",
            mem: 12, memType: "HBM2", bw: 0.653, bf16: 110,
            tdp: 250, ic: "PCIe 3.0", icGBs: 16, scaleUp: 1,
            price: 2_999, rent: nil, transistors: 21.1,
            image: "p100_die", rep: true, fact: "A full Volta die with Tensor Cores for $2,999 — the researcher's budget pick."),
        acc("v100_32", "Tesla V100 SXM2 32GB", .nvidia, .datacenter, arch: "Volta",
            announced: YM(2018, 3), available: YM(2018, 4), discontinued: YM(2022, 6), process: "TSMC 12nm FFN",
            mem: 32, memType: "HBM2", bw: 0.9, bf16: 125,
            tdp: 300, ic: "NVLink 2.0 / NVSwitch", icGBs: 300, scaleUp: 16,
            price: 11_500, rent: 3.06, rentFloor: 0.50, transistors: 21.1,
            image: "p100_die", rep: true, fact: "DGX-2 joined 16 of these with NVSwitch. GPT-3 was trained on V100s.",
            est: "price"),

        // MARK: - NVIDIA consumer & workstation
        acc("rtx3090", "GeForce RTX 3090", .nvidia, .consumer, arch: "Ampere",
            announced: YM(2020, 9), available: YM(2020, 9), discontinued: YM(2022, 12), process: "Samsung 8nm",
            mem: 24, memType: "GDDR6X", bw: 0.936, bf16: 71, int8: 284,
            tdp: 350, ic: "NVLink bridge", icGBs: 112.5, scaleUp: 2,
            price: 1_499, rent: 0.45, rentFloor: 0.18, transistors: 28.3,
            image: "rtx_3090", fact: "The last GeForce with an NVLink bridge. BF16 runs at half rate with FP32 accumulate."),
        acc("rtx4090", "GeForce RTX 4090", .nvidia, .consumer, arch: "Ada Lovelace",
            announced: YM(2022, 9), available: YM(2022, 10), discontinued: YM(2024, 10), process: "TSMC 4N",
            mem: 24, memType: "GDDR6X", bw: 1.008, bf16: 165.2, fp8: 330.3, int8: 660.6,
            tdp: 450, ic: "PCIe 4.0", icGBs: 32, scaleUp: 1,
            price: 1_599, rent: 0.75, rentFloor: 0.30, transistors: 76.3,
            image: "rtx_4090", fact: "First GeForce with FP8 tensor cores — but no NVLink, so multi-GPU runs over PCIe."),
        acc("rtx5090", "GeForce RTX 5090", .nvidia, .consumer, arch: "Blackwell",
            announced: YM(2025, 1), available: YM(2025, 1), process: "TSMC 4N",
            mem: 32, memType: "GDDR7", bw: 1.792, bf16: 209.5, fp8: 419, fp4: 1_676, int8: 838,
            tdp: 575, ic: "PCIe 5.0", icGBs: 64, scaleUp: 1,
            price: 1_999, rent: 0.89, rentFloor: 0.45, transistors: 92.2,
            image: "rtx_5090", fact: "5th-gen tensor cores with native FP4: 1,676 dense FP4 TFLOPS on a gaming card."),
        acc("rtxpro6000", "RTX PRO 6000 Blackwell", .nvidia, .workstation, arch: "Blackwell",
            announced: YM(2025, 3), available: YM(2025, 4), process: "TSMC 4N",
            mem: 96, memType: "GDDR7 ECC", bw: 1.792, bf16: 500, fp8: 1_000, fp4: 2_000, int8: 1_000,
            tdp: 600, ic: "PCIe 5.0", icGBs: 64, scaleUp: 1,
            price: 8_565, rent: 1.79, rentFloor: 0.9, transistors: 92.2,
            image: "rtx_5090", rep: true, fact: "96 GB on a single card — fine-tune a 70B model at your desk.",
            est: "bf16, fp8"),
        acc("m2ultra", "Mac Studio M2 Ultra 192GB", .apple, .workstation, arch: "Apple M2 Ultra",
            announced: YM(2023, 6), available: YM(2023, 6), discontinued: YM(2025, 3), process: "TSMC N5P",
            mem: 192, memType: "Unified LPDDR5", bw: 0.8, bf16: 27.2,
            tdp: 295, ic: "Thunderbolt 4", icGBs: 5, scaleUp: 1,
            price: 6_599, rent: nil, transistors: 134,
            image: "mac_studio", rep: true, fact: "192 GB of unified memory in a desktop box — runs a 180B model with 4-bit weights.",
            est: "tdp", decodeEff: 0.6, mfu: 0.22),
        acc("m3ultra", "Mac Studio M3 Ultra 512GB", .apple, .workstation, arch: "Apple M3 Ultra",
            announced: YM(2025, 3), available: YM(2025, 3), process: "TSMC N3B",
            mem: 512, memType: "Unified LPDDR5", bw: 0.819, bf16: 28,
            tdp: 300, ic: "Thunderbolt 5", icGBs: 15, scaleUp: 1,
            price: 9_499, rent: nil, transistors: 184,
            image: "mac_studio", rep: true, fact: "512 GB unified memory: hobbyists run 600B+ MoE models at home.",
            est: "bf16, tdp", decodeEff: 0.6, mfu: 0.22),
        acc("dgxspark", "DGX Spark (GB10)", .nvidia, .workstation, arch: "Grace Blackwell",
            announced: YM(2025, 1), available: YM(2025, 10), process: "TSMC 3nm",
            mem: 128, memType: "Unified LPDDR5x", bw: 0.273, bf16: 125, fp8: 250, fp4: 500, int8: 250,
            tdp: 240, ic: "ConnectX-7 200GbE", icGBs: 25, scaleUp: 2,
            price: 3_999, rent: nil,
            image: "dgx_spark", fact: "A petaflop (sparse FP4) desktop supercomputer — but only 273 GB/s of bandwidth.",
            est: "bf16, fp8", mfu: 0.3),

        // MARK: - NVIDIA datacenter
        acc("a100_40", "A100 SXM 40GB", .nvidia, .datacenter, arch: "Ampere",
            announced: YM(2020, 5), available: YM(2020, 6), discontinued: YM(2024, 1), process: "TSMC 7nm",
            mem: 40, memType: "HBM2", bw: 1.555, bf16: 312, int8: 624,
            tdp: 400, ic: "NVLink 3.0", icGBs: 600, scaleUp: 8,
            price: 10_000, rent: 4.10, rentFloor: 0.8, transistors: 54.2,
            image: "h100_stack", rep: true, fact: "Introduced BF16 and TF32 tensor cores; the workhorse of the GPT-3 → GPT-4 era.",
            est: "price"),
        acc("a100_80", "A100 SXM 80GB", .nvidia, .datacenter, arch: "Ampere",
            announced: YM(2020, 11), available: YM(2020, 12), discontinued: YM(2024, 6), process: "TSMC 7nm",
            mem: 80, memType: "HBM2e", bw: 2.039, bf16: 312, int8: 624,
            tdp: 400, ic: "NVLink 3.0", icGBs: 600, scaleUp: 8,
            price: 15_000, rent: 4.10, rentFloor: 1.0, transistors: 54.2,
            image: "h100_stack", rep: true, fact: "80 GB HBM2e at 2 TB/s. GPT-4 was trained on ~25,000 of these.",
            est: "price"),
        acc("a10", "A10 24GB", .nvidia, .datacenter, arch: "Ampere (GA102)",
            announced: YM(2021, 4), available: YM(2021, 5), process: "Samsung 8nm",
            mem: 24, memType: "GDDR6", bw: 0.6, bf16: 125, int8: 250,
            tdp: 150, ic: "PCIe 4.0", icGBs: 32, scaleUp: 1,
            price: 3_500, rent: 1.0, rentFloor: 0.35, transistors: 28.3,
            image: "h100_cards", rep: true, fact: "The GA102 workhorse behind AWS's A10G instances: cheap, plentiful inference for 7–13B models.",
            est: "price"),
        acc("h100_pcie", "H100 PCIe 80GB", .nvidia, .datacenter, arch: "Hopper",
            announced: YM(2022, 3), available: YM(2022, 11), process: "TSMC 4N",
            mem: 80, memType: "HBM2e", bw: 2.0, bf16: 756, fp8: 1_513, int8: 1_513,
            tdp: 350, ic: "NVLink bridge", icGBs: 600, scaleUp: 2,
            price: 25_000, rent: 3.30, rentFloor: 1.6, transistors: 80,
            image: "h100_cards", fact: "Hopper on a standard PCIe card — easier to deploy, ~25% slower than SXM."),
        acc("h100_sxm", "H100 SXM5 80GB", .nvidia, .datacenter, arch: "Hopper",
            announced: YM(2022, 3), available: YM(2022, 12), process: "TSMC 4N",
            mem: 80, memType: "HBM3", bw: 3.35, bf16: 989, fp8: 1_979, int8: 1_979,
            tdp: 700, ic: "NVLink 4.0", icGBs: 900, scaleUp: 8,
            price: 30_000, rent: 6.60, rentFloor: 1.9, transistors: 80,
            image: "h100_stack", rep: true, fact: "The GPU of the 2023 gold rush: Transformer Engine + FP8, with 6+ month waitlists."),
        acc("h200", "H200 SXM 141GB", .nvidia, .datacenter, arch: "Hopper",
            announced: YM(2023, 11), available: YM(2024, 7), process: "TSMC 4N",
            mem: 141, memType: "HBM3e", bw: 4.8, bf16: 989, fp8: 1_979, int8: 1_979,
            tdp: 700, ic: "NVLink 4.0", icGBs: 900, scaleUp: 8,
            price: 32_000, rent: 4.50, rentFloor: 2.2, transistors: 80,
            image: "h100_stack", rep: true, fact: "Same Hopper die as H100 with 76% more memory and 43% more bandwidth.",
            est: "price"),
        acc("l4", "L4 24GB", .nvidia, .datacenter, arch: "Ada Lovelace",
            announced: YM(2023, 3), available: YM(2023, 3), process: "TSMC 4N",
            mem: 24, memType: "GDDR6", bw: 0.3, bf16: 121, fp8: 242.5, int8: 242.5,
            tdp: 72, ic: "PCIe 4.0", icGBs: 32, scaleUp: 1,
            price: 2_500, rent: 0.70, rentFloor: 0.28, transistors: 35.8,
            image: "h100_cards", rep: true, fact: "The T4's successor: Ada Lovelace in 72 W, with FP8 for dense, cheap inference fleets.",
            est: "price"),
        acc("l40s", "L40S 48GB", .nvidia, .datacenter, arch: "Ada Lovelace",
            announced: YM(2023, 8), available: YM(2023, 10), process: "TSMC 4N",
            mem: 48, memType: "GDDR6 ECC", bw: 0.864, bf16: 362, fp8: 733, int8: 733,
            tdp: 350, ic: "PCIe 4.0", icGBs: 32, scaleUp: 1,
            price: 8_500, rent: 1.50, rentFloor: 0.60, transistors: 76.3,
            image: "h100_cards", rep: true, fact: "48 GB and FP8 on a PCIe card: pitched as the no-waitlist alternative during the 2023 H100 shortage.",
            est: "price, rent"),
        acc("gh200", "GH200 Grace Hopper 96GB", .nvidia, .datacenter, arch: "Hopper + Grace",
            announced: YM(2023, 5), available: YM(2024, 2), process: "TSMC 4N",
            mem: 96, memType: "HBM3 (+480 GB LPDDR5X)", bw: 4.0, bf16: 989, fp8: 1_979, int8: 1_979,
            tdp: 1_000, ic: "NVLink-C2C", icGBs: 900, scaleUp: 2,
            price: 35_000, rent: 2.49, rentFloor: 1.2, liquid: true, transistors: 80,
            image: "h100_stack", rep: true, fact: "An H100 fused to a 72-core Grace CPU over a 900 GB/s link: 576 GB of fast memory per superchip.",
            est: "price, rent"),
        acc("b200", "B200 (HGX)", .nvidia, .datacenter, arch: "Blackwell",
            announced: YM(2024, 3), available: YM(2024, 12), process: "TSMC 4NP",
            mem: 180, memType: "HBM3e", bw: 8.0, bf16: 2_250, fp8: 4_500, fp4: 9_000, int8: 4_500,
            tdp: 1_000, ic: "NVLink 5", icGBs: 1_800, scaleUp: 8,
            price: 40_000, rent: 6.50, rentFloor: 3.0, transistors: 208,
            image: "hgx_b200", fact: "Two reticle-limit dies fused by a 10 TB/s link: 208 billion transistors.",
            est: "price"),
        acc("gb200", "GB200 NVL72 (per GPU)", .nvidia, .datacenter, arch: "Blackwell",
            announced: YM(2024, 3), available: YM(2025, 2), process: "TSMC 4NP",
            mem: 186, memType: "HBM3e", bw: 8.0, bf16: 2_500, fp8: 5_000, fp4: 10_000, int8: 5_000,
            tdp: 1_200, ic: "NVLink 5 (NVL72)", icGBs: 1_800, scaleUp: 72,
            price: 43_000, rent: 6.00, rentFloor: 3.2, liquid: true, transistors: 208,
            image: "gb200_rack", fact: "72 GPUs wired as one giant GPU over a 130 TB/s NVLink spine. ~$3M per rack.",
            est: "price"),
        acc("gb300", "GB300 NVL72 / B300", .nvidia, .datacenter, arch: "Blackwell Ultra",
            announced: YM(2025, 3), available: YM(2025, 9), process: "TSMC 4NP",
            mem: 288, memType: "HBM3e", bw: 8.0, bf16: 2_500, fp8: 5_000, fp4: 15_000,
            tdp: 1_400, ic: "NVLink 5 (NVL72)", icGBs: 1_800, scaleUp: 72,
            price: 55_000, rent: 8.90, rentFloor: 4.0, liquid: true, transistors: 208,
            image: "b200_rack", rep: true, fact: "Blackwell Ultra: 1.5x the FP4 of B200 and 288 GB HBM3e (INT8 was cut).",
            est: "price"),
        acc("rubin", "Vera Rubin VR200 NVL72", .nvidia, .datacenter, arch: "Rubin",
            announced: YM(2025, 3), available: YM(2026, 10), process: "TSMC 3nm",
            mem: 288, memType: "HBM4", bw: 22.0, bf16: 8_750, fp8: 17_500, fp4: 50_000,
            tdp: 1_800, ic: "NVLink 6", icGBs: 3_600, scaleUp: 72,
            price: 60_000, rent: 11.0, rentFloor: 5.0, liquid: true, transistors: 336,
            image: "gb200_rack", rep: true,
            fact: "50 PF NVFP4 for inference (35 PF for training) and HBM4 at 22 TB/s per GPU. Samples shipped Feb 2026; production in Q3 and volume in Q4 2026.",
            est: "bf16, fp8, tdp, price, rent", trainFP4: 0.7),
        acc("rubin_cpx", "Rubin CPX", .nvidia, .datacenter, arch: "Rubin",
            announced: YM(2025, 9), available: YM(2026, 12), process: "TSMC 3nm",
            mem: 128, memType: "GDDR7", bw: 2.0, bf16: 5_000, fp8: 10_000, fp4: 30_000,
            tdp: 800, ic: "NVL144 CPX", icGBs: 900, scaleUp: 144,
            price: 25_000, rent: 5.0, rentFloor: 2.5, liquid: true,
            image: "b200_rack", rep: true,
            fact: "A context-prefill specialist: cheap GDDR7 instead of HBM, built for million-token prompts.",
            est: "bw, bf16, fp8, tdp, price, rent", decodeEff: 0.4, trainFP4: 0.6),
        acc("rubin_ultra", "Rubin Ultra NVL576", .nvidia, .datacenter, arch: "Rubin Ultra",
            announced: YM(2025, 3), available: YM(2027, 10), process: "TSMC 3nm",
            mem: 1_024, memType: "HBM4e", bw: 32.0, bf16: 17_500, fp8: 35_000, fp4: 100_000,
            tdp: 3_600, ic: "NVLink 7 (Kyber)", icGBs: 3_600, scaleUp: 144,
            price: 120_000, rent: 20.0, rentFloor: 8.0, liquid: true,
            image: "gb200_rack", rep: true,
            fact: "Four reticle-sized dies and 1 TB of HBM4e per package; 600 kW Kyber racks. Roadmap specs.",
            est: "bw, bf16, fp8, tdp, price, rent, ic", trainFP4: 0.7),
        acc("feynman", "Feynman (roadmap)", .nvidia, .datacenter, arch: "Feynman",
            announced: YM(2025, 3), available: YM(2028, 10), process: "TSMC A16 (est)",
            mem: 2_048, memType: "HBM5 (est)", bw: 64.0, bf16: 35_000, fp8: 70_000, fp4: 200_000,
            tdp: 4_500, ic: "NVLink 8 (est)", icGBs: 7_200, scaleUp: 144,
            price: 180_000, rent: 30.0, rentFloor: 12, liquid: true,
            image: "supercomputer", rep: true,
            fact: "Only the name is public. Every number here is a game estimate for the 2028 generation.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.75),
        acc("groq3_lpx", "Groq 3 LPU (LPX rack)", .nvidia, .wafer, arch: "Groq LP30",
            announced: YM(2026, 3), available: YM(2026, 9), process: "Undisclosed",
            mem: 0.5, memType: "On-chip SRAM", bw: 150, bf16: 600, fp8: 1_200,
            tdp: 450, ic: "LPX scale-up (640 TB/s per rack)", icGBs: 2_500, scaleUp: 256,
            price: 35_000, rent: 2.0, rentFloor: 0.9, liquid: true,
            image: "groq_lpu", rep: true,
            fact: "NVIDIA's decode co-processor built on licensed Groq technology: ~500 MB of SRAM at 150 TB/s per chip, 256 per LPX rack beside Vera Rubin. Shown at GTC 2026.",
            est: "bf16, tdp, price, rent", decodeEff: 0.0012),
        acc("rtx_spark", "RTX Spark (N1X)", .nvidia, .workstation, arch: "Blackwell (N1X)",
            announced: YM(2026, 6), available: YM(2026, 10), process: "TSMC 3nm (est)",
            mem: 128, memType: "LPDDR5X unified", bw: 0.3, bf16: 125, fp8: 250, fp4: 1_000,
            tdp: 80, ic: "None", icGBs: 0, scaleUp: 1,
            price: 3_000, rent: nil,
            image: "dgx_spark", rep: true,
            fact: "NVIDIA's PC superchip from Computex 2026: up to 128 GB of unified memory and ~1 PF of FP4 in a 45–80 W laptop or mini-PC.",
            est: "bf16, fp8, price, process"),

        // MARK: - Google TPUs (cloud only)
        acc("tpu_v2", "TPU v2", .google, .tpu, arch: "TPU v2",
            announced: YM(2017, 5), available: YM(2018, 2), process: "16nm (est)",
            mem: 16, memType: "HBM", bw: 0.6, bf16: 45,
            tdp: 280, ic: "ICI 2D torus", icGBs: 62, scaleUp: 256,
            price: nil, rent: 1.125, rentFloor: 0.3,
            image: "tpu_v3", rep: true, fact: "The first TPU that could train — and the chip that introduced bfloat16.",
            est: "tdp, ic, process"),
        acc("tpu_v3", "TPU v3", .google, .tpu, arch: "TPU v3",
            announced: YM(2018, 5), available: YM(2018, 12), process: "16nm (est)",
            mem: 32, memType: "HBM2", bw: 0.9, bf16: 123,
            tdp: 262, ic: "ICI 2D torus", icGBs: 82, scaleUp: 1_024,
            price: nil, rent: 2.0, rentFloor: 0.55, liquid: true,
            image: "tpu_v3", fact: "Liquid-cooled boards; a 1,024-chip pod delivers 126 PFLOPS of BF16.",
            est: "ic, process"),
        acc("tpu_v4", "TPU v4", .google, .tpu, arch: "TPU v4",
            announced: YM(2021, 5), available: YM(2022, 5), process: "7nm",
            mem: 32, memType: "HBM2", bw: 1.2, bf16: 275,
            tdp: 192, ic: "ICI 3D torus + OCS", icGBs: 300, scaleUp: 4_096,
            price: nil, rent: 3.22, rentFloor: 1.0, liquid: true,
            image: "tpu_v4", fact: "Optical circuit switches rewire a 4,096-chip pod in seconds. PaLM trained here.",
            est: "ic"),
        acc("tpu_v5e", "TPU v5e", .google, .tpu, arch: "TPU v5e",
            announced: YM(2023, 8), available: YM(2023, 8), process: "5nm (est)",
            mem: 16, memType: "HBM2e", bw: 0.819, bf16: 197, int8: 394,
            tdp: 160, ic: "ICI 2D torus", icGBs: 200, scaleUp: 256,
            price: nil, rent: 1.20, rentFloor: 0.54,
            image: "tpu_v4", rep: true, fact: "The cost-optimized TPU: best performance-per-dollar of 2023.",
            est: "tdp, process"),
        acc("tpu_v5p", "TPU v5p", .google, .tpu, arch: "TPU v5p",
            announced: YM(2023, 12), available: YM(2023, 12), process: "5nm (est)",
            mem: 95, memType: "HBM2e", bw: 2.765, bf16: 459, int8: 918,
            tdp: 450, ic: "ICI 3D torus", icGBs: 600, scaleUp: 8_960,
            price: nil, rent: 4.20, rentFloor: 1.89, liquid: true,
            image: "tpu_v4", rep: true, fact: "8,960-chip pods built for training frontier Gemini models.",
            est: "tdp, process"),
        acc("tpu_v6e", "TPU v6e Trillium", .google, .tpu, arch: "Trillium",
            announced: YM(2024, 5), available: YM(2024, 12), process: "4nm (est)",
            mem: 32, memType: "HBM", bw: 1.64, bf16: 918, int8: 1_836,
            tdp: 300, ic: "ICI 2D torus", icGBs: 448, scaleUp: 256,
            price: nil, rent: 2.70, rentFloor: 1.22, liquid: true,
            image: "tpu_v4", rep: true, fact: "4.7x the peak compute of v5e per chip, and 67% more energy efficient.",
            est: "tdp, process"),
        acc("tpu7x", "TPU7x Ironwood", .google, .tpu, arch: "Ironwood",
            announced: YM(2025, 4), available: YM(2025, 11), process: "3nm (est)",
            mem: 192, memType: "HBM3e", bw: 7.37, bf16: 2_307, fp8: 4_614, int8: 4_614,
            tdp: 1_000, ic: "ICI 3D torus + OCS", icGBs: 1_200, scaleUp: 9_216,
            price: 28_000, rent: 12.0, rentFloor: 5.4, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "A 9,216-chip pod delivers 42.5 FP8 exaflops. Google now sells TPU racks for customers' own datacenters (sold in 64-chip racks).",
            est: "tdp, process, price", minOrder: 64),
        acc("tpu8t", "TPU 8t \"Sunfish\"", .google, .tpu, arch: "TPU 8 (training)",
            announced: YM(2026, 4), available: YM(2026, 10), process: "TSMC 3nm (est)",
            mem: 216, memType: "HBM3e", bw: 6.5, bf16: 3_150, fp8: 6_300, fp4: 12_600,
            tdp: 1_100, ic: "ICI 19.2 Tb/s + Virgo", icGBs: 2_400, scaleUp: 9_600,
            price: 45_000, rent: 16.0, rentFloor: 7.0, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Training TPU: 9,600-chip superpods with 2 PB of HBM and 121 FP4 exaflops; Virgo links 134K chips. Best for self-improvement runs.",
            est: "bf16, fp8, tdp, rent, price, process", minOrder: 64),
        acc("tpu8i", "TPU 8i \"Zebrafish\"", .google, .tpu, arch: "TPU 8 (inference)",
            announced: YM(2026, 4), available: YM(2026, 10), process: "TSMC 3nm (est)",
            mem: 288, memType: "HBM3e", bw: 8.6, bf16: 2_525, fp8: 5_050, fp4: 10_100,
            tdp: 900, ic: "ICI 19.2 Tb/s Boardfly", icGBs: 2_400, scaleUp: 1_152,
            price: 32_000, rent: 9.5, rentFloor: 4.5, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Inference TPU with 384 MB on-chip SRAM (3x Ironwood) and ~80% better perf/$ for LLM serving.",
            est: "bf16, fp8, tdp, rent, price, process", decodeEff: 0.8, minOrder: 64),

        // MARK: - AMD Instinct
        acc("mi250x", "Instinct MI250X", .amd, .datacenter, arch: "CDNA 2",
            announced: YM(2021, 11), available: YM(2021, 11), discontinued: YM(2025, 1), process: "TSMC 6nm",
            mem: 128, memType: "HBM2e", bw: 3.2, bf16: 383, int8: 383,
            tdp: 560, ic: "Infinity Fabric", icGBs: 800, scaleUp: 8,
            price: 14_000, rent: 2.1, rentFloor: 0.8, transistors: 58.2,
            image: "amd_instinct", rep: true, fact: "Powered Frontier, the world's first exascale supercomputer.",
            est: "price, rent", mfu: 0.33),
        acc("mi300x", "Instinct MI300X", .amd, .datacenter, arch: "CDNA 3",
            announced: YM(2023, 6), available: YM(2023, 12), process: "TSMC 5nm + 6nm",
            mem: 192, memType: "HBM3", bw: 5.3, bf16: 1_307, fp8: 2_615, int8: 2_615,
            tdp: 750, ic: "Infinity Fabric", icGBs: 896, scaleUp: 8,
            price: 15_000, rent: 4.0, rentFloor: 1.9, transistors: 153,
            image: "amd_instinct", rep: true, fact: "192 GB of HBM3 — 2.4x an H100 — made it an inference favourite.",
            est: "price", mfu: 0.36),
        acc("mi325x", "Instinct MI325X", .amd, .datacenter, arch: "CDNA 3",
            announced: YM(2024, 6), available: YM(2025, 1), process: "TSMC 5nm + 6nm",
            mem: 256, memType: "HBM3e", bw: 6.0, bf16: 1_307, fp8: 2_615, int8: 2_615,
            tdp: 1_000, ic: "Infinity Fabric", icGBs: 896, scaleUp: 8,
            price: 20_000, rent: 3.0, rentFloor: 2.0, transistors: 153,
            image: "amd_instinct", fact: "256 GB HBM3e on one accelerator.",
            est: "price, rent", mfu: 0.36),
        acc("mi355x", "Instinct MI355X", .amd, .datacenter, arch: "CDNA 4",
            announced: YM(2025, 6), available: YM(2025, 8), process: "TSMC N3P",
            mem: 288, memType: "HBM3e", bw: 8.0, bf16: 2_500, fp8: 5_000, fp4: 10_000, int8: 5_000,
            tdp: 1_400, ic: "Infinity Fabric", icGBs: 1_075, scaleUp: 8,
            price: 25_000, rent: 3.5, rentFloor: 2.3, liquid: true, transistors: 185,
            image: "amd_instinct", rep: true, fact: "Matches B200-class FP4/FP8 with 288 GB HBM3e at a lower price.",
            est: "price, rent, ic", mfu: 0.37),
        acc("mi455x", "Instinct MI455X (Helios)", .amd, .datacenter, arch: "CDNA 5",
            announced: YM(2025, 6), available: YM(2026, 7), process: "TSMC N2 + N3",
            mem: 432, memType: "HBM4", bw: 23.3, bf16: 10_000, fp8: 20_100, fp4: 40_300,
            tdp: 2_300, ic: "UALink / Infinity Fabric", icGBs: 3_600, scaleUp: 72,
            price: 52_000, rent: 9.0, rentFloor: 4.0, liquid: true, transistors: 320,
            image: "amd_racks", rep: true, fact: "432 GB of HBM4 per GPU — 1.5x Rubin's capacity. Helios racks hold 72 GPUs and 18 EPYC Venice CPUs; in production from Jul 2026.",
            est: "bf16, tdp, price, rent", mfu: 0.38),
        acc("mi350p", "Instinct MI350P (PCIe)", .amd, .datacenter, arch: "CDNA 4",
            announced: YM(2026, 5), available: YM(2026, 5), process: "TSMC 3nm",
            mem: 144, memType: "HBM3e", bw: 4.0, bf16: 2_300, fp8: 4_600, fp4: 4_600,
            tdp: 600, ic: "PCIe 5.0", icGBs: 128, scaleUp: 1,
            price: 22_000, rent: 2.6, rentFloor: 1.2,
            image: "amd_instinct", rep: true,
            fact: "An air-cooled PCIe card with 144 GB of HBM3E for ordinary servers — about 40% more FP16/FP8 than an H200 NVL, but no GPU fabric.",
            est: "price, rent"),
        acc("mi500", "Instinct MI500 (roadmap)", .amd, .datacenter, arch: "CDNA 6",
            announced: YM(2026, 1), available: YM(2027, 9), process: "TSMC 2nm",
            mem: 576, memType: "HBM4E", bw: 36.0, bf16: 20_000, fp8: 40_000, fp4: 80_000,
            tdp: 2_600, ic: "UALink (est)", icGBs: 3_600, scaleUp: 72,
            price: 75_000, rent: 14.0, rentFloor: 6.0, liquid: true,
            image: "amd_racks", rep: true,
            fact: "Previewed at CES 2026 for the Helios 500 rack with EPYC \"Verano\"; MI600 follows in 2028. AMD hasn't published specs — these are game estimates.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic", mfu: 0.39),

        // MARK: - Intel
        acc("gaudi2", "Gaudi 2", .intel, .custom, arch: "Gaudi 2",
            announced: YM(2022, 5), available: YM(2022, 7), process: "TSMC 7nm",
            mem: 96, memType: "HBM2e", bw: 2.45, bf16: 432, fp8: 865, int8: 865,
            tdp: 600, ic: "24x 100GbE RoCE", icGBs: 300, scaleUp: 8,
            price: 8_000, rent: 1.30, rentFloor: 0.7,
            image: "wafer_closeup", rep: true, fact: "Ethernet-native: 24 x 100 GbE RoCE ports right on the die.",
            est: "bf16, fp8, price", mfu: 0.33),
        acc("gaudi3", "Gaudi 3", .intel, .custom, arch: "Gaudi 3",
            announced: YM(2024, 4), available: YM(2024, 10), process: "TSMC 5nm",
            mem: 128, memType: "HBM2e", bw: 3.7, bf16: 1_835, fp8: 1_835, int8: 1_835,
            tdp: 900, ic: "24x 200GbE RoCE", icGBs: 600, scaleUp: 8,
            price: 15_600, rent: 2.0, rentFloor: 1.1,
            image: "wafer_closeup", rep: true, fact: "About half the price of an H100 kit, with 1,835 TFLOPS of BF16 and FP8.",
            est: "rent", mfu: 0.33),

        acc("crescent", "Crescent Island", .intel, .datacenter, arch: "Xe3P (32 cores)",
            announced: YM(2025, 10), available: YM(2027, 3), process: "Undisclosed",
            mem: 160, memType: "LPDDR5X", bw: 0.68, bf16: 300, fp8: 600, fp4: 1_200, int8: 600,
            tdp: 350, ic: "PCIe 5.0", icGBs: 64, scaleUp: 8,
            price: 8_000, rent: 1.20, rentFloor: 0.5,
            image: "wafer_closeup", rep: true,
            fact: "Inference-only GPU: 256 XMX engines, 160 GB of LPDDR5X instead of HBM, air-cooled at 350 W. Sampling late 2026.",
            est: "bw, bf16, fp8, fp4, int8, price, rent, ic, available", decodeEff: 0.7, mfu: 0.25),
        // MARK: - AWS (cloud only)
        acc("trn1", "Trainium", .aws, .custom, arch: "NeuronCore-v2",
            announced: YM(2020, 12), available: YM(2022, 10), process: "TSMC 7nm",
            mem: 32, memType: "HBM2e", bw: 0.82, bf16: 190, fp8: 190,
            tdp: 400, ic: "NeuronLink", icGBs: 384, scaleUp: 16,
            price: nil, rent: 1.34, rentFloor: 0.7,
            image: "wafer_closeup", rep: true, fact: "Amazon's first training chip, sold as trn1.32xlarge instances.",
            est: "tdp, ic"),
        acc("trn2", "Trainium2", .aws, .custom, arch: "NeuronCore-v3",
            announced: YM(2023, 11), available: YM(2024, 12), process: "TSMC 5nm",
            mem: 96, memType: "HBM3", bw: 2.9, bf16: 667, fp8: 1_299,
            tdp: 500, ic: "NeuronLink v3", icGBs: 1_280, scaleUp: 64,
            price: nil, rent: 2.80, rentFloor: 1.3,
            image: "wafer_closeup", rep: true, fact: "Project Rainier strung together ~500,000 Trainium2 chips for one customer.",
            est: "tdp, ic"),
        acc("trn3", "Trainium3", .aws, .custom, arch: "NeuronCore-v4",
            announced: YM(2024, 12), available: YM(2025, 12), process: "TSMC 3nm",
            mem: 144, memType: "HBM3e", bw: 4.9, bf16: 671, fp8: 2_517, fp4: 2_517,
            tdp: 1_000, ic: "NeuronSwitch-v1", icGBs: 2_000, scaleUp: 144,
            price: nil, rent: 4.5, rentFloor: 2.2, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Trn3 UltraServer: 144 chips, 362 FP8 PFLOPS. MXFP4 runs through the FP8 path.",
            est: "tdp, ic, rent"),
        acc("trn4", "Trainium4", .aws, .custom, arch: "NeuronCore-v5 (est)",
            announced: YM(2025, 12), available: YM(2027, 6), process: "TSMC 3nm (est)",
            mem: 288, memType: "HBM4", bw: 19.6, bf16: 1_900, fp8: 7_600, fp4: 15_000,
            tdp: 1_400, ic: "NVLink Fusion", icGBs: 3_600, scaleUp: 144,
            price: nil, rent: 8.0, rentFloor: 3.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Previewed at re:Invent 2025 with NVLink Fusion inside NVIDIA MGX racks; a big lab plans ~2 GW of Trainium3/4. Specs are estimates scaled from AWS's stated gains over Trainium3.",
            est: "mem, bw, bf16, fp8, fp4, tdp, rent, process"),

        acc("inf2", "Inferentia2", .aws, .custom, arch: "NeuronCore-v2 (inference)",
            announced: YM(2022, 11), available: YM(2023, 4), process: "TSMC 7nm (est)",
            mem: 32, memType: "HBM", bw: 0.82, bf16: 190, fp8: 190, int8: 380,
            tdp: 175, ic: "NeuronLink-v2", icGBs: 192, scaleUp: 12,
            price: nil, rent: 0.76, rentFloor: 0.30,
            image: "wafer_closeup", rep: true,
            fact: "AWS's own inference chip: an inf2.xlarge rents one for about $0.76/hour; inf2.48xlarge links 12.",
            est: "process, tdp, ic", decodeEff: 0.7, mfu: 0.25),
        // MARK: - Microsoft
        acc("maia200", "Maia 200", .microsoft, .custom, arch: "Maia 2",
            announced: YM(2026, 1), available: YM(2026, 3), process: "TSMC 3nm",
            mem: 216, memType: "HBM3e", bw: 7.0, bf16: 2_536, fp8: 5_072, fp4: 10_140,
            tdp: 750, ic: "On-die Ethernet", icGBs: 2_800, scaleUp: 6_144,
            price: nil, rent: 7.0, rentFloor: 3.5, liquid: true, transistors: 140,
            image: "wafer", rep: true,
            fact: "272 MB on-die SRAM in a 750 W envelope. Azure-internal in reality — rentable in this game.",
            est: "bf16, rent", decodeEff: 0.72),
        acc("maia300", "Maia 300", .microsoft, .custom, arch: "Maia 3",
            announced: YM(2026, 10), available: YM(2027, 4), process: "TSMC N2P",
            mem: 288, memType: "HBM4", bw: 18.0, bf16: 3_450, fp8: 6_900, fp4: 13_800,
            tdp: 950, ic: "Ethernet scale-up", icGBs: 3_600, scaleUp: 96,
            price: nil, rent: 9.0, rentFloor: 4.0, liquid: true,
            image: "wafer", rep: true,
            fact: "N2P compute chiplets and eight HBM4 stacks; 96 accelerators per 167 kW rack, built for multi-gigawatt Azure deployments from 2027.",
            est: "bf16, ic, rent", decodeEff: 0.72),

        // MARK: - Qualcomm & Tenstorrent
        acc("qai100u", "Cloud AI 100 Ultra", .qualcomm, .custom, arch: "Hexagon NPU (4 dies)",
            announced: YM(2023, 11), available: YM(2024, 3), process: "TSMC 7nm",
            mem: 128, memType: "LPDDR4x", bw: 0.548, bf16: 288, int8: 870,
            tdp: 150, ic: "PCIe 4.0", icGBs: 32, scaleUp: 16,
            price: 12_000, rent: 1.10, rentFloor: 0.45,
            image: "wafer_closeup", rep: true,
            fact: "Four AI 100 dies and 576 MB of SRAM on one 150 W card, which holds a 100B-parameter model in a single slot.",
            est: "bf16, mem, bw, price, rent, available", decodeEff: 0.7, mfu: 0.22),
        acc("qai200", "Qualcomm AI200", .qualcomm, .custom, arch: "Hexagon NPU (rack-scale)",
            announced: YM(2025, 10), available: YM(2026, 12), process: "Undisclosed",
            mem: 768, memType: "LPDDR", bw: 1.2, bf16: 500, fp8: 1_000, int8: 2_000,
            tdp: 600, ic: "PCIe scale-up + Ethernet", icGBs: 64, scaleUp: 72,
            price: 15_000, rent: 2.0, rentFloor: 0.9, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "768 GB of LPDDR per card, so huge models fit on a few chips. 160 kW liquid-cooled racks; HUMAIN plans 200 MW of them.",
            est: "bw, bf16, fp8, int8, tdp, price, rent, ic, available", decodeEff: 0.72, mfu: 0.22),
        acc("qai250", "Qualcomm AI250", .qualcomm, .custom, arch: "Near-memory compute",
            announced: YM(2025, 10), available: YM(2027, 6), process: "Undisclosed",
            mem: 768, memType: "LPDDR (near-memory)", bw: 8.0, bf16: 600, fp8: 1_200, int8: 2_400,
            tdp: 700, ic: "PCIe scale-up + Ethernet", icGBs: 64, scaleUp: 72,
            price: 18_000, rent: 2.6, rentFloor: 1.1, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Compute next to memory, promising >10× the effective memory bandwidth of AI200. Built for decode-heavy serving.",
            est: "mem, bw, bf16, fp8, int8, tdp, price, rent, ic, available", decodeEff: 0.8, mfu: 0.22),
        acc("bh_p150a", "Blackhole p150a", .tenstorrent, .workstation, arch: "Blackhole (Tensix + RISC-V)",
            announced: YM(2024, 8), available: YM(2025, 4), process: "TSMC 6nm",
            mem: 32, memType: "GDDR6", bw: 0.512, bf16: 332, fp8: 664,
            tdp: 300, ic: "4x QSFP-DD 800G", icGBs: 400, scaleUp: 32,
            price: 1_399, rent: 0.60, rentFloor: 0.25,
            image: "wafer_closeup", rep: true,
            fact: "Jim Keller's RISC-V AI card: 32 GB and 664 block-FP8 TFLOPS for $1,399, chained over Ethernet. The software is still maturing.",
            est: "bf16, rent", mfu: 0.24),

        // MARK: - Wafer-scale & SRAM machines
        acc("cs3", "Cerebras CS-3 (WSE-3)", .cerebras, .wafer, arch: "WSE-3",
            announced: YM(2024, 3), available: YM(2024, 6), process: "TSMC 5nm",
            mem: 44, memType: "On-wafer SRAM", bw: 21_000, bf16: 62_500,
            tdp: 23_000, ic: "SwarmX + MemoryX", icGBs: 150, scaleUp: 2_048,
            price: 2_500_000, rent: 300, rentFloor: 150, liquid: true, transistors: 4_000,
            image: "wafer", rep: true,
            fact: "One 46,225 mm² wafer: 900,000 cores, 4 trillion transistors and 21 PB/s of memory bandwidth.",
            est: "bf16, price, rent, ic", decodeEff: 0.004, streaming: true),
        acc("cs4", "Cerebras CS-4 (3× WSE-3 Turbo)", .cerebras, .wafer, arch: "WSE-3 Turbo",
            announced: YM(2026, 8), available: YM(2026, 9), process: "TSMC 5nm",
            mem: 132, memType: "On-wafer SRAM", bw: 129_600, bf16: 375_000,
            tdp: 70_000, ic: "SwarmX + MemoryX", icGBs: 900, scaleUp: 2_048,
            price: 7_500_000, rent: 900, rentFloor: 450, liquid: true, transistors: 12_000,
            image: "wafer", rep: true,
            fact: "Three wafers in one system: 132 GB of SRAM and 129.6 PB/s of memory bandwidth. Cerebras went public in May 2026.",
            est: "bf16, tdp, price, rent, ic", decodeEff: 0.004, streaming: true),
        acc("groq", "Groq LPU v1", .groq, .wafer, arch: "TSP",
            announced: YM(2020, 1), available: YM(2024, 2), process: "GlobalFoundries 14nm",
            mem: 0.23, memType: "On-chip SRAM", bw: 80, bf16: 188, int8: 750,
            tdp: 300, ic: "RealScale C2C", icGBs: 330, scaleUp: 10_000,
            price: 20_000, rent: 0.80, rentFloor: 0.4, transistors: 26.8,
            image: "groq_lpu", fact: "No HBM at all — 230 MB SRAM at 80 TB/s. Hundreds of chips serve one model, very fast.",
            est: "tdp, price, rent, ic", decodeEff: 0.0012),
        acc("dojo", "Tesla Dojo Training Tile", .tesla, .wafer, arch: "Dojo D1 x25",
            announced: YM(2021, 8), available: YM(2023, 7), discontinued: YM(2025, 8), process: "TSMC 7nm",
            mem: 11, memType: "On-tile SRAM", bw: 36, bf16: 9_050,
            tdp: 15_000, ic: "Dojo Interface Processor", icGBs: 4_500, scaleUp: 120,
            price: 1_000_000, rent: nil, liquid: true, transistors: 1_250,
            image: "dojo_tile", fact: "25 D1 dies fused on one tile. Tesla wound the project down in August 2025.",
            est: "bw, price, ic", decodeEff: 0.05, streaming: true, mfu: 0.30),

        // MARK: - Huawei Ascend
        acc("ascend910b", "Ascend 910B", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2023, 3), available: YM(2023, 6), process: "SMIC 7nm (N+2)",
            mem: 64, memType: "HBM2e", bw: 1.6, bf16: 320, int8: 640,
            tdp: 400, ic: "HCCS", icGBs: 392, scaleUp: 8,
            price: 12_000, rent: 2.0, rentFloor: 1.0,
            image: "wafer_closeup", rep: true, fact: "China's main H100 alternative after US export controls tightened.",
            est: "bf16, int8, price, rent", mfu: 0.30),
        acc("ascend910c", "Ascend 910C", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2024, 8), available: YM(2025, 3), process: "SMIC 7nm (N+2)",
            mem: 128, memType: "HBM2e", bw: 3.2, bf16: 780,
            tdp: 600, ic: "HCCS + optical", icGBs: 350, scaleUp: 384,
            price: 25_000, rent: 3.0, rentFloor: 1.5,
            image: "wafer_closeup", rep: true, fact: "Two 910B dies in one package; CloudMatrix 384 links 384 of them optically.",
            est: "bf16, tdp, price, rent", mfu: 0.30),
        acc("ascend950dt", "Ascend 950DT", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2025, 9), available: YM(2026, 12), process: "SMIC N+3 (est)",
            mem: 144, memType: "HiZQ 2.0 HBM", bw: 4.0, bf16: 500, fp8: 1_000, fp4: 2_000,
            tdp: 600, ic: "UnifiedBus", icGBs: 2_000, scaleUp: 8_192,
            price: 22_000, rent: 3.0, rentFloor: 1.5,
            image: "wafer_closeup", rep: true, fact: "Huawei's own HBM: 144 GB at 4 TB/s, aimed at decode and training.",
            est: "bf16, tdp, price, rent, process", mfu: 0.32),
        acc("ascend950pr", "Ascend 950PR (Atlas 350)", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2026, 3), available: YM(2026, 3), process: "SMIC N+3 (est)",
            mem: 112, memType: "HiBL 1.0 HBM", bw: 1.4, bf16: 500, fp8: 1_000, fp4: 1_560,
            tdp: 600, ic: "UnifiedBus", icGBs: 2_000, scaleUp: 8,
            price: 15_000, rent: 2.2, rentFloor: 1.0,
            image: "wafer_closeup", rep: true,
            fact: "Huawei's in-house HBM on a 600 W card; Huawei claims 2.8× an H20. Chinese hyperscalers are reported buyers as H200 imports stall.",
            est: "bf16, process, price, rent", mfu: 0.30),
        acc("ascend960", "Ascend 960 (roadmap)", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2025, 9), available: YM(2027, 12), process: "SMIC (est)",
            mem: 288, memType: "Huawei HBM", bw: 9.6, bf16: 1_000, fp8: 2_000, fp4: 4_000,
            tdp: 800, ic: "UnifiedBus 2.0", icGBs: 4_000, scaleUp: 15_488,
            price: 30_000, rent: 4.0, rentFloor: 2.0,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap part for the Atlas 960 SuperPoD of 15,488 chips, with Huawei's HiF4 4-bit format.",
            est: "bf16, tdp, process, price, rent", mfu: 0.31),
        acc("ascend970", "Ascend 970 (roadmap)", .huawei, .custom, arch: "Da Vinci",
            announced: YM(2025, 9), available: YM(2028, 12), process: "SMIC (est)",
            mem: 288, memType: "Huawei HBM", bw: 14.4, bf16: 2_000, fp8: 4_000, fp4: 8_000,
            tdp: 900, ic: "UnifiedBus 2.0", icGBs: 4_000, scaleUp: 15_488,
            price: 38_000, rent: 5.0, rentFloor: 2.5,
            image: "wafer_closeup", rep: true,
            fact: "The last part on Huawei's public roadmap: 4 TB/s interconnect and double the 960's compute.",
            est: "bf16, tdp, process, price, rent", mfu: 0.32),

        // MARK: - 3.4: the roadmap past 2028 (game projections)
        // Nothing here is announced before 2027. Trends continue the catalogue's: flagship dense BF16 per chip roughly
        // doubles a year, BF16 per watt grows ~1.45× a year, BF16 per dollar ~1.3× and rent per PFLOP-hour falls ~23%
        // a year. Names past Feynman are placeholders; every number is an estimate.
        acc("feynman_ultra", "Feynman Ultra (roadmap)", .nvidia, .datacenter, arch: "Feynman Ultra",
            announced: YM(2027, 3), available: YM(2029, 10), process: "TSMC A16 (est)",
            mem: 3_072, memType: "HBM5 (est)", bw: 96.0, bf16: 60_000, fp8: 120_000, fp4: 360_000,
            tdp: 5_500, ic: "NVLink 8 (est)", icGBs: 7_200, scaleUp: 288,
            price: 240_000, rent: 40.0, rentFloor: 15, liquid: true,
            image: "gb200_rack", rep: true,
            fact: "Roadmap projection: Feynman's dies doubled up on one package with 3 TB of HBM5, in racks of 288. A game estimate for NVIDIA's 2029 part.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),
        acc("noether", "Noether (roadmap)", .nvidia, .datacenter, arch: "Noether (placeholder)",
            announced: YM(2028, 3), available: YM(2030, 10), process: "TSMC A14 (est)",
            mem: 4_608, memType: "HBM5E (est)", bw: 140.0, bf16: 95_000, fp8: 190_000, fp4: 600_000,
            tdp: 6_500, ic: "NVLink 9 (est)", icGBs: 10_000, scaleUp: 288,
            price: 300_000, rent: 52.0, rentFloor: 20, liquid: true,
            image: "supercomputer", rep: true,
            fact: "Roadmap projection: the architecture after Feynman, with co-packaged optics on every package so whole halls act as one NVLink domain. Name and specs are placeholders.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),
        acc("noether_ultra", "Noether Ultra (roadmap)", .nvidia, .datacenter, arch: "Noether Ultra (placeholder)",
            announced: YM(2029, 3), available: YM(2031, 10), process: "TSMC A14 (est)",
            mem: 6_144, memType: "HBM5E (est)", bw: 200.0, bf16: 160_000, fp8: 320_000, fp4: 1_000_000,
            tdp: 7_500, ic: "NVLink 9 optical (est)", icGBs: 14_400, scaleUp: 576,
            price: 380_000, rent: 66.0, rentFloor: 25, liquid: true,
            image: "gb200_rack", rep: true,
            fact: "Roadmap projection: a full exaflop of FP4 per package and 576-way optical scale-up. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),
        acc("meitner", "Meitner (roadmap)", .nvidia, .datacenter, arch: "Meitner (placeholder)",
            announced: YM(2030, 3), available: YM(2032, 10), process: "Sub-1nm class (est)",
            mem: 8_192, memType: "HBM6 (est)", bw: 300.0, bf16: 260_000, fp8: 520_000, fp4: 1_600_000,
            tdp: 8_500, ic: "Optical NVLink (est)", icGBs: 14_400, scaleUp: 576,
            price: 460_000, rent: 80.0, rentFloor: 30, liquid: true,
            image: "supercomputer", rep: true,
            fact: "Roadmap projection: backside power, 3D-stacked logic and HBM6. A rack of these out-computes 2024's largest cluster. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),
        acc("meitner_ultra", "Meitner Ultra (roadmap)", .nvidia, .datacenter, arch: "Meitner Ultra (placeholder)",
            announced: YM(2031, 3), available: YM(2033, 10), process: "Sub-1nm class (est)",
            mem: 12_288, memType: "HBM6E (est)", bw: 420.0, bf16: 420_000, fp8: 840_000, fp4: 2_600_000,
            tdp: 9_500, ic: "Optical NVLink (est)", icGBs: 20_000, scaleUp: 1_152,
            price: 560_000, rent: 96.0, rentFloor: 36, liquid: true,
            image: "gb200_rack", rep: true,
            fact: "Roadmap projection: 1,152 packages in one optical scale-up domain. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),
        acc("wu", "Wu (roadmap)", .nvidia, .datacenter, arch: "Wu (placeholder)",
            announced: YM(2032, 3), available: YM(2034, 10), process: "Sub-1nm class (est)",
            mem: 16_384, memType: "3D-stacked DRAM (est)", bw: 600.0, bf16: 680_000, fp8: 1_360_000, fp4: 4_200_000,
            tdp: 10_500, ic: "Optical NVLink (est)", icGBs: 28_800, scaleUp: 1_152,
            price: 680_000, rent: 115.0, rentFloor: 42, liquid: true,
            image: "supercomputer", rep: true,
            fact: "Roadmap projection: memory stacked directly on the logic, so bandwidth stops being the bottleneck. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", trainFP4: 0.8),

        acc("tpu9", "TPU 9 (roadmap)", .google, .tpu, arch: "TPU 9 (est)",
            announced: YM(2028, 4), available: YM(2028, 11), process: "TSMC 2nm (est)",
            mem: 384, memType: "HBM4 (est)", bw: 16.0, bf16: 9_000, fp8: 18_000, fp4: 36_000,
            tdp: 1_400, ic: "ICI + OCS (est)", icGBs: 3_600, scaleUp: 9_600,
            price: 60_000, rent: 18.0, rentFloor: 7.5, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Roadmap projection: the next TPU after 8t/8i, in 9,600-chip superpods (sold in 64-chip racks). A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", minOrder: 64),
        acc("tpu10", "TPU 10 (roadmap)", .google, .tpu, arch: "TPU 10 (est)",
            announced: YM(2030, 4), available: YM(2030, 11), process: "TSMC A14 (est)",
            mem: 768, memType: "HBM5 (est)", bw: 40.0, bf16: 32_000, fp8: 64_000, fp4: 128_000,
            tdp: 2_000, ic: "Optical ICI (est)", icGBs: 7_200, scaleUp: 16_384,
            price: 130_000, rent: 32.0, rentFloor: 12, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Roadmap projection: 16,384-chip optical pods, and the best performance per watt on the market at launch. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", minOrder: 64),
        acc("tpu11", "TPU 11 (roadmap)", .google, .tpu, arch: "TPU 11 (est)",
            announced: YM(2032, 4), available: YM(2032, 11), process: "Sub-1nm class (est)",
            mem: 1_536, memType: "HBM6 (est)", bw: 100.0, bf16: 100_000, fp8: 200_000, fp4: 400_000,
            tdp: 3_000, ic: "Optical ICI (est)", icGBs: 14_400, scaleUp: 32_768,
            price: 240_000, rent: 52.0, rentFloor: 20, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Roadmap projection: 32,768-chip pods spanning several buildings. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", minOrder: 64),
        acc("tpu12", "TPU 12 (roadmap)", .google, .tpu, arch: "TPU 12 (est)",
            announced: YM(2034, 4), available: YM(2034, 11), process: "Sub-1nm class (est)",
            mem: 3_072, memType: "3D-stacked DRAM (est)", bw: 240.0, bf16: 300_000, fp8: 600_000, fp4: 1_200_000,
            tdp: 4_000, ic: "Optical ICI (est)", icGBs: 28_800, scaleUp: 65_536,
            price: 400_000, rent: 85.0, rentFloor: 32, liquid: true,
            image: "tpu_v4", rep: true,
            fact: "Roadmap projection: 65,536-chip pods. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", minOrder: 64),

        acc("mi600", "Instinct MI600 (roadmap)", .amd, .datacenter, arch: "CDNA 7 (est)",
            announced: YM(2027, 6), available: YM(2028, 9), process: "TSMC A16 (est)",
            mem: 1_152, memType: "HBM5 (est)", bw: 64.0, bf16: 40_000, fp8: 80_000, fp4: 200_000,
            tdp: 4_000, ic: "UALink 2 (est)", icGBs: 7_200, scaleUp: 144,
            price: 150_000, rent: 24.0, rentFloor: 9, liquid: true,
            image: "amd_racks", rep: true,
            fact: "Roadmap projection for the MI500's successor: more memory per GPU than anyone, at a lower price than NVIDIA. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.40),
        acc("mi700", "Instinct MI700 (roadmap)", .amd, .datacenter, arch: "CDNA 8 (est)",
            announced: YM(2029, 6), available: YM(2030, 9), process: "TSMC A14 (est)",
            mem: 2_304, memType: "HBM5E (est)", bw: 140.0, bf16: 110_000, fp8: 220_000, fp4: 550_000,
            tdp: 6_000, ic: "UALink 3 (est)", icGBs: 10_000, scaleUp: 288,
            price: 280_000, rent: 46.0, rentFloor: 17, liquid: true,
            image: "amd_racks", rep: true,
            fact: "Roadmap projection: 2.3 TB of HBM per GPU and open UALink racks of 288. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.40),
        acc("mi800", "Instinct MI800 (roadmap)", .amd, .datacenter, arch: "CDNA 9 (est)",
            announced: YM(2031, 6), available: YM(2032, 9), process: "Sub-1nm class (est)",
            mem: 4_608, memType: "HBM6 (est)", bw: 300.0, bf16: 300_000, fp8: 600_000, fp4: 1_500_000,
            tdp: 8_000, ic: "UALink optical (est)", icGBs: 14_400, scaleUp: 576,
            price: 450_000, rent: 72.0, rentFloor: 27, liquid: true,
            image: "amd_racks", rep: true,
            fact: "Roadmap projection: AMD's bid to lead on raw compute per dollar. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.40),
        acc("mi900", "Instinct MI900 (roadmap)", .amd, .datacenter, arch: "CDNA 10 (est)",
            announced: YM(2033, 6), available: YM(2034, 9), process: "Sub-1nm class (est)",
            mem: 9_216, memType: "3D-stacked DRAM (est)", bw: 600.0, bf16: 750_000, fp8: 1_500_000, fp4: 3_750_000,
            tdp: 10_000, ic: "UALink optical (est)", icGBs: 28_800, scaleUp: 1_152,
            price: 720_000, rent: 118.0, rentFloor: 44, liquid: true,
            image: "amd_racks", rep: true,
            fact: "Roadmap projection: memory stacked on logic, 9 TB per package. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.40),

        acc("trn5", "Trainium5 (roadmap)", .aws, .custom, arch: "NeuronCore-v6 (est)",
            announced: YM(2028, 12), available: YM(2029, 12), process: "TSMC 2nm (est)",
            mem: 576, memType: "HBM5 (est)", bw: 40.0, bf16: 6_000, fp8: 24_000, fp4: 48_000,
            tdp: 1_800, ic: "NeuronSwitch (est)", icGBs: 7_200, scaleUp: 288,
            price: nil, rent: 11.0, rentFloor: 4.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: AWS keeps betting on cheap FP8 at enormous scale, rented by the UltraServer. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, rent, ic, process"),
        acc("trn6", "Trainium6 (roadmap)", .aws, .custom, arch: "NeuronCore-v7 (est)",
            announced: YM(2030, 12), available: YM(2031, 12), process: "TSMC A14 (est)",
            mem: 1_152, memType: "HBM5E (est)", bw: 90.0, bf16: 20_000, fp8: 80_000, fp4: 160_000,
            tdp: 2_600, ic: "NeuronSwitch optical (est)", icGBs: 14_400, scaleUp: 576,
            price: nil, rent: 20.0, rentFloor: 8, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: the cheapest FP8 PFLOP-hour in any cloud at launch. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, rent, ic, process"),
        acc("maia400", "Maia 400 (roadmap)", .microsoft, .custom, arch: "Maia 4 (est)",
            announced: YM(2028, 10), available: YM(2029, 5), process: "TSMC A16 (est)",
            mem: 432, memType: "HBM5 (est)", bw: 30.0, bf16: 9_000, fp8: 18_000, fp4: 36_000,
            tdp: 1_300, ic: "Ethernet scale-up (est)", icGBs: 7_200, scaleUp: 192,
            price: nil, rent: 14.0, rentFloor: 5.5, liquid: true,
            image: "wafer", rep: true,
            fact: "Roadmap projection: Azure's inference workhorse for the 2030s, with a large on-die SRAM. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, rent, ic, process", decodeEff: 0.72),
        acc("ascend980", "Ascend 980 (roadmap)", .huawei, .custom, arch: "Da Vinci (est)",
            announced: YM(2028, 9), available: YM(2029, 12), process: "SMIC (est)",
            mem: 512, memType: "Huawei HBM (est)", bw: 20.0, bf16: 4_000, fp8: 8_000, fp4: 16_000,
            tdp: 1_100, ic: "UnifiedBus 3.0 (est)", icGBs: 8_000, scaleUp: 15_488,
            price: 45_000, rent: 6.0, rentFloor: 2.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: still a generation behind on the chip, made up for with enormous SuperPoDs. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.33),
        acc("ascend990", "Ascend 990 (roadmap)", .huawei, .custom, arch: "Da Vinci (est)",
            announced: YM(2030, 9), available: YM(2031, 12), process: "SMIC (est)",
            mem: 768, memType: "Huawei HBM (est)", bw: 36.0, bf16: 9_000, fp8: 18_000, fp4: 36_000,
            tdp: 1_400, ic: "UnifiedBus 3.0 (est)", icGBs: 8_000, scaleUp: 15_488,
            price: 60_000, rent: 9.0, rentFloor: 3.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: Huawei's domestic supply chain closes the gap a little more each year. A game estimate.",
            est: "mem, bw, bf16, fp8, fp4, tdp, price, rent, ic, process", mfu: 0.33),
        acc("cs5", "Cerebras CS-5 (WSE-4, roadmap)", .cerebras, .wafer, arch: "WSE-4 (est)",
            announced: YM(2028, 3), available: YM(2029, 3), process: "TSMC 2nm (est)",
            mem: 300, memType: "On-wafer SRAM", bw: 300_000, bf16: 1_000_000,
            tdp: 85_000, ic: "SwarmX + MemoryX (est)", icGBs: 1_800, scaleUp: 2_048,
            price: 12_000_000, rent: 1_500, rentFloor: 600, liquid: true,
            image: "wafer", rep: true,
            fact: "Roadmap projection: the next wafer-scale engine, with 300 GB of SRAM on the wafer. A game estimate.",
            est: "mem, bw, bf16, tdp, price, rent, ic, process", decodeEff: 0.004, streaming: true),
        acc("cs6", "Cerebras CS-6 (WSE-5, roadmap)", .cerebras, .wafer, arch: "WSE-5 (est)",
            announced: YM(2031, 3), available: YM(2032, 3), process: "Sub-1nm class (est)",
            mem: 800, memType: "On-wafer SRAM + stacked DRAM", bw: 900_000, bf16: 3_000_000,
            tdp: 98_000, ic: "SwarmX optical (est)", icGBs: 3_600, scaleUp: 4_096,
            price: 20_000_000, rent: 2_800, rentFloor: 1_100, liquid: true,
            image: "wafer", rep: true,
            fact: "Roadmap projection: DRAM bonded straight onto the wafer. A game estimate.",
            est: "mem, bw, bf16, tdp, price, rent, ic, process", decodeEff: 0.004, streaming: true),
        acc("lumen_px1", "Lumen PX1 photonic (roadmap)", .intel, .custom, arch: "Silicon-photonic matrix engine (est)",
            announced: YM(2030, 3), available: YM(2031, 6), process: "Silicon photonics + 18A (est)",
            mem: 384, memType: "HBM5 (est)", bw: 24.0, bf16: 6_000, fp8: 120_000, fp4: 240_000, int8: 120_000,
            tdp: 900, ic: "Optical I/O (est)", icGBs: 7_200, scaleUp: 256,
            price: 85_000, rent: 11.0, rentFloor: 4.0, liquid: true,
            image: "fiber", rep: true,
            fact: "Roadmap projection: matrix multiplies done with light. About twice the inference per watt of any GPU at launch, but poor at training. Fictional product; a game estimate.",
            est: "mem, bw, bf16, fp8, fp4, int8, tdp, price, rent, ic, process", decodeEff: 0.7, mfu: 0.2),
        acc("ai500_analog", "Qualcomm AI500 analog (roadmap)", .qualcomm, .custom, arch: "Analog in-memory compute (est)",
            announced: YM(2029, 10), available: YM(2030, 12), process: "Undisclosed (est)",
            mem: 1_536, memType: "LPDDR6 with in-memory compute (est)", bw: 60.0, bf16: 2_500, fp8: 20_000, int8: 40_000,
            tdp: 350, ic: "PCIe 7 + Ethernet (est)", icGBs: 256, scaleUp: 72,
            price: 30_000, rent: 4.0, rentFloor: 1.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: weights stay put in analog memory cells and the maths happens where they sit. 1.5 TB per card at 350 W. A game estimate.",
            est: "mem, bw, bf16, fp8, int8, tdp, price, rent, ic, process", decodeEff: 0.85, mfu: 0.18),
        acc("synapse_n3", "Synapse N3 neuromorphic (roadmap)", .intel, .custom, arch: "Neuromorphic event-driven cores (est)",
            announced: YM(2032, 3), available: YM(2033, 6), process: "Intel 14A (est)",
            mem: 768, memType: "Stacked DRAM (est)", bw: 80.0, bf16: 4_000, fp8: 80_000, int8: 160_000,
            tdp: 400, ic: "Optical I/O (est)", icGBs: 3_600, scaleUp: 256,
            price: 60_000, rent: 7.0, rentFloor: 2.5, liquid: true,
            image: "wafer_closeup", rep: true,
            fact: "Roadmap projection: spiking, event-driven inference where only the neurons that change do any work. The most tokens per watt you can buy. Fictional product; a game estimate.",
            est: "mem, bw, bf16, fp8, int8, tdp, price, rent, ic, process", decodeEff: 0.9, mfu: 0.15),
    ]

    static let byID: [String: Accelerator] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Player-designed chips, registered from the current game state.
    nonisolated(unsafe) private(set) static var custom: [String: Accelerator] = [:]

    static func get(_ id: String) -> Accelerator? { byID[id] ?? custom[id] }

    static var everything: [Accelerator] { all + custom.values.sorted { $0.available < $1.available } }

    static func register(_ chips: [CustomChip]) {
        var map: [String: Accelerator] = [:]
        for c in chips {
            let ym = c.available.ym
            map[c.id] = acc(c.id, c.name, .custom, .custom,
                            arch: c.alien ? "Alien architecture (agent-designed, gen \(c.generation))" : "Custom \(c.focus.rawValue.lowercased()) ASIC (gen \(c.generation))",
                            announced: ym, available: ym, process: c.process,
                            mem: c.memoryGB, memType: c.memoryType, bw: c.bandwidthTBs,
                            bf16: c.bf16, fp8: c.fp8, fp4: c.fp4, int8: c.fp8,
                            tdp: c.tdpW, ic: "Custom scale-up fabric", icGBs: 1_800, scaleUp: c.scaleUp,
                            price: c.unitCost, rent: nil, liquid: c.alien ? false : c.tdpW > 900,
                            image: c.alien ? "wafer_closeup" : (c.focus == .training ? "wafer" : "wafer_closeup"), rep: true,
                            fact: c.alien ? "Designed by your agent swarm. Nobody fully understands how it works — it just does, at a fraction of the cost, and air cooling is enough."
                                          : "Your own silicon: built only for you, at cost.", decodeEff: c.decodeEff)
        }
        custom = map
    }

    /// The reference chip used for "H100-equivalents".
    static let h100 = byID["h100_sxm"]!
}
