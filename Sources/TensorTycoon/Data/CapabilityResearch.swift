import Foundation

// MARK: - 3.4: research that widens what models can do

extension ResearchCatalog {
    private static func cap(_ id: String, _ name: String, _ cat: ResearchCategory, _ year: Double, _ cost: Double,
                            _ prereqs: [String], _ effects: [ResearchEffect], _ blurb: String) -> ResearchItem {
        ResearchItem(id: id, name: name, category: cat, year: year, cost: cost, prereqs: prereqs, effects: effects, blurb: blurb)
    }

    /// Techniques that raise capability domains (robotics, voice, science, memory…) and open product lines. Real dates up
    /// to 2026, projected after. They only move domain scores, never the index or training, so the core race plays as
    /// before; public ones older than a new game's start are already known.
    static let capabilityTech: [ResearchItem] = [
        // MARK: Robotics
        cap("sim_to_real", "Sim-to-Real Robot Training", .multimodal, 2019.8, 280, [],
            [.domain(.robotics, 0.2)],
            "Oct 2019: a robot hand trained only in simulation, with physics randomised every episode, solved a Rubik's cube in the real world. Robots can practise millions of times before touching anything."),
        cap("embodied_fm", "Embodied Foundation Models", .multimodal, 2024.83, 3_200, ["vla"],
            [.domain(.robotics, 0.45), .product("robotics")],
            "Late 2024: one generalist policy, trained on data from eight kinds of robot arm, folds laundry, buses tables and packs boxes. Robot makers start licensing robot brains instead of writing their own."),
        cap("robot_world_models", "World Models for Robot Planning", .multimodal, 2025.45, 4_500, ["embodied_fm", "video"],
            [.domain(.robotics, 0.3), .domain(.vision, 0.05)],
            "Jun 2025: a model pre-trained on a million hours of video plans robot actions by imagining their outcome first, picking up objects in labs it had never seen."),
        cap("humanoid_control", "Whole-Body Humanoid Control", .multimodal, 2026.35, 7_000, ["robot_world_models"],
            [.domain(.robotics, 0.35)],
            "2026: humanoids that walk, carry and work with both hands under one learned controller, recovering from slips and shoves. Pilot deployments in warehouses and car plants."),
        cap("dexterous_manipulation", "Dexterous Manipulation at Scale", .multimodal, 2027.4, 14_000, ["humanoid_control"],
            [.domain(.robotics, 0.4)],
            "Projected for 2027: five-fingered hands handle cables, fabric, food and tools as well as a trained worker, learned from fleets of teleoperated and autonomous robots."),
        cap("home_robotics", "Safe Home Robotics", .multimodal, 2029.2, 38_000, ["dexterous_manipulation", "robot_fm"],
            [.domain(.robotics, 0.45), .domain(.social, 0.05)],
            "Projected for 2029: robots safe and reliable enough for homes with children and pets — laundry, dishes, tidying — trained on years of fleet experience."),
        cap("surgical_autonomy", "Autonomous Surgical Robotics", .science, 2029.8, 42_000, ["dexterous_manipulation", "clinical_grounding"],
            [.domain(.robotics, 0.25), .domain(.science, 0.1)],
            "Projected for 2029–30: robots that perform routine operations end to end under a surgeon's supervision. In 2025 one removed a gallbladder from a pig with no hands on the controls."),

        // MARK: Vision & video
        cap("long_video", "Long-Video Understanding", .multimodal, 2024.15, 2_600, ["native_multimodal", "ring_attention"],
            [.domain(.vision, 0.1), .domain(.memory, 0.05)],
            "Feb 2024: a million-token context took in an hour of video and answered questions about any moment in it."),
        cap("video_dit", "Video Diffusion at Scale", .multimodal, 2024.95, 3_400, ["video"],
            [.domain(.vision, 0.15), .product("video")],
            "Dec 2024: video models released to the public render minutes of 1080p–4K footage with consistent characters and plausible physics. Studios and ad agencies start paying for it."),
        cap("world_simulators", "Interactive World Simulators", .multimodal, 2025.6, 5_000, ["video_dit"],
            [.domain(.vision, 0.12), .domain(.robotics, 0.1)],
            "Aug 2025: a model generates a playable 3D world from a prompt at 24 frames a second and keeps it consistent for minutes. A training ground for agents and robots."),

        // MARK: Voice
        cap("audio_codecs", "Neural Audio Codecs", .multimodal, 2021.55, 500, ["transformer"],
            [.domain(.voice, 0.15)],
            "Jul 2021: neural codecs compress speech and music into discrete tokens a language model can read and write, at 3–6 kbps. The basis of every voice-native model since."),
        cap("full_duplex_voice", "Full-Duplex Voice Models", .multimodal, 2024.7, 2_600, ["audio"],
            [.domain(.voice, 0.25), .domain(.social, 0.05), .product("voice")],
            "Sep 2024: models that listen while they speak, with about 200 ms of lag, backchannels and interruptions — talking to one finally feels like a phone call."),
        cap("expressive_speech", "Expressive Speech & Emotion", .multimodal, 2025.15, 2_800, ["full_duplex_voice"],
            [.domain(.voice, 0.15), .domain(.social, 0.08)],
            "Feb 2025: conversational speech models that pick up on tone and answer with timing, laughter and emotion. Listeners in blind tests often preferred them to recordings of people."),

        // MARK: Science & math
        cap("protein_design", "Generative Protein Design", .science, 2022.95, 1_200, ["alphafold"],
            [.domain(.science, 0.15)],
            "Dec 2022: diffusion models designed protein binders from scratch, and many worked in the lab on the first try. Design, not just prediction."),
        cap("clinical_grounding", "Clinical Reasoning & Grounding", .science, 2023.4, 1_500, ["rlhf", "rag"],
            [.domain(.science, 0.08), .domain(.knowledge, 0.08), .product("health")],
            "May 2023: a medical fine-tune scored 86.5% on licensing-exam questions, and physicians preferred its answers to doctors' on most axes. Grounded in guidelines and citations, it's ready for clinics."),
        cap("hypothesis_agents", "Hypothesis-Generating Agents", .science, 2025.13, 3_600, ["deep_research"],
            [.domain(.science, 0.15), .domain(.reasoning, 0.03)],
            "Feb 2025: a multi-agent system read the literature, debated hypotheses and proposed drug-repurposing candidates for leukaemia that then worked in the lab."),
        cap("formal_verification", "Formal Verification in the Loop", .reasoning, 2025.3, 4_200, ["formal_math"],
            [.domain(.math, 0.2), .domain(.coding, 0.05)],
            "2025: provers that write Lean proofs step by step and get each one checked, reaching gold-medal olympiad scores with fully formal proofs. Wrong answers stop slipping through."),
        cap("lab_automation", "Autonomous Lab Automation", .science, 2025.75, 5_500, ["hypothesis_agents", "agents"],
            [.domain(.science, 0.3), .domain(.robotics, 0.05), .product("science")],
            "2025: self-driving labs where models plan experiments and robotic benches run them around the clock. Pharma and materials companies pay for discoveries, not software."),
        cap("autoformalization", "Autoformalisation", .science, 2026.6, 7_500, ["formal_verification", "co_mathematician"],
            [.domain(.math, 0.25)],
            "Projected for late 2026: models translate whole papers and textbooks into machine-checked mathematics. Every published proof becomes something a model can build on."),
        cap("virtual_cell", "Virtual Cell Models", .science, 2027.8, 16_000, ["lab_automation", "protein_design"],
            [.domain(.science, 0.35)],
            "Projected for 2027–28: models trained on billions of single-cell measurements predict how a cell responds to a drug or an edit before anyone runs the experiment."),
        cap("math_discovery", "Machine-Guided Mathematical Discovery", .science, 2028.2, 26_000, ["autoformalization"],
            [.domain(.math, 0.35)],
            "Projected for 2028: models that pose their own conjectures, search for proofs over weeks and hand mathematicians results worth publishing."),

        // MARK: Agents & memory
        cap("gui_grounding", "Pixel-Level Screen Grounding", .agents, 2025.07, 2_800, ["computer_use"],
            [.domain(.agents, 0.1), .domain(.vision, 0.08), .product("operator")],
            "Jan 2025: agents that look at screenshots, click and type through any app without an API, trained with reinforcement learning on thousands of real tasks. Back offices start buying them by the task."),
        cap("long_term_memory", "Long-Term Memory Architectures", .agents, 2025.28, 3_000, ["rag", "long_context"],
            [.domain(.memory, 0.25)],
            "Apr 2025: assistants that remember every past conversation and use it without being asked, with memory the user can inspect and edit."),
        cap("tool_scale", "Tool Use at Scale", .agents, 2025.85, 3_500, ["mcp"],
            [.domain(.agents, 0.15), .domain(.coding, 0.05)],
            "Late 2025: agents that search a library of thousands of tools, load only what they need and write code to chain them. Context stops filling up with tool definitions."),
        cap("episodic_memory", "Episodic Memory Consolidation", .agents, 2027.2, 13_000, ["long_term_memory", "nested_learning"],
            [.domain(.memory, 0.3), .domain(.agents, 0.05)],
            "Projected for 2027: like sleep for models — each day's experience is distilled into lasting memories and skills without forgetting the old ones."),
        cap("lifelong_memory", "Lifelong Personal Memory", .agents, 2030.2, 48_000, ["episodic_memory"],
            [.domain(.memory, 0.35), .domain(.social, 0.05)],
            "Projected for 2030: an assistant that remembers years of your life — every meeting, document and decision — and reasons over all of it."),

        // MARK: People, forecasting, deployment
        cap("theory_of_mind", "Theory-of-Mind Evaluation", .postTraining, 2023.15, 1_100, ["rlhf"],
            [.domain(.social, 0.15)],
            "Feb 2023: false-belief tests borrowed from child psychology showed the newest models passing most of them, and a year of argument about what that means. Labs start training and testing for it."),
        cap("pedagogy", "Pedagogical Fine-Tuning", .postTraining, 2024.4, 1_500, ["rlhf"],
            [.domain(.social, 0.1), .domain(.knowledge, 0.03), .product("tutor")],
            "May 2024: models tuned on learning science — ask instead of tell, adapt to the student, check understanding. Schools and parents start paying for tutors."),
        cap("sovereign_deploy", "Air-Gapped Sovereign Deployment", .safety, 2024.45, 2_200, ["evals_rsp"],
            [.domain(.agents, 0.03), .product("government")],
            "2024: frontier models cleared to run on classified, air-gapped government clouds, with audit trails and on-premise weights. Governments and defence ministries sign their first contracts."),
        cap("forecasting_rl", "Forecasting with Live Feedback", .reasoning, 2025.6, 3_800, ["reasoning_rl"],
            [.domain(.reasoning, 0.08), .domain(.knowledge, 0.1)],
            "2025: reinforcement learning on thousands of questions that resolve later — elections, prices, conflicts. Bots close in on the best human forecasting teams."),
        cap("cyber_defense", "Autonomous Cyber Defence", .safety, 2025.6, 5_000, ["vuln_discovery", "agents"],
            [.domain(.coding, 0.1), .domain(.agents, 0.05)],
            "Aug 2025: in a government challenge, autonomous systems found and patched dozens of real vulnerabilities in open-source software with no human help."),
    ]

    static let capabilityTechIDs: Set<String> = Set(capabilityTech.map(\.id))

    /// How the research director weighs an item: domain-only research ranks below the core (it doesn't make models
    /// smarter or cheaper), research that opens a product line ranks like the rest.
    static func directorWeight(_ item: ResearchItem) -> Double {
        guard capabilityTechIDs.contains(item.id) else { return 1 }
        return item.effects.contains { if case .product = $0 { return true } else { return false } } ? 1 : 0.5
    }
}
