export const patientsData = [
    {
        id: "VS-0012",
        name: "Ramesh Kumar",
        age: 65,
        gender: "Male",
        location: "Pune Rural",
        status: "critical", // stable, warning, critical
        vitals: {
            hr: 112,
            bp: "155/95",
            spo2: 92,
            temp: 37.8
        },
        alerts: [
            "High HR detected (112 BPM)",
            "BP elevated since last reading"
        ],
        rxEfficacy: {
            medication: "Telmisartan 40mg",
            improvement: "-12% BP avg over 7 days"
        },
        history: [
            { date: "2026-02-20", hr: 110, bp: "158/98", notes: "Patient reported dizziness." },
            { date: "2026-02-21", hr: 108, bp: "152/94", notes: "Vitals slightly improved." },
            { date: "2026-02-22", hr: 115, bp: "160/100", notes: "Critical alert triggered." }
        ],
        weeklySummary: "Patient exhibits hypertensive urgency with persistent tachycardia. Blood pressure remains significantly elevated despite current dosage of Telmisartan. Recommended immediate dose adjustment and 24h monitoring."
    },
    {
        id: "VS-0045",
        name: "Sunita Deshmukh",
        age: 58,
        gender: "Female",
        location: "Nashik",
        status: "warning",
        vitals: {
            hr: 82,
            bp: "135/85",
            spo2: 95,
            temp: 36.5
        },
        alerts: [
            "Irregular heartbeat detected at 2:00 AM"
        ],
        rxEfficacy: {
            medication: "Atenolol 50mg",
            improvement: "HR stabilized to 75-85 BPM range"
        },
        history: [
            { date: "2026-02-18", hr: 85, bp: "140/90", notes: "Irregular intervals observed." },
            { date: "2026-02-22", hr: 82, bp: "135/85", notes: "Stable with current medication." }
        ],
        weeklySummary: "Heart rate trends are within acceptable ranges (75-85 BPM), however, nocturnal arrhythmia episodes persist. BP shows a moderate downward trend. Continue current regimen with close monitoring of sleep vitals."
    },
    {
        id: "VS-0078",
        name: "Prakash Patel",
        age: 72,
        gender: "Male",
        location: "Solapur",
        status: "stable",
        vitals: {
            hr: 68,
            bp: "118/78",
            spo2: 98,
            temp: 36.6
        },
        alerts: [],
        rxEfficacy: {
            medication: "Amlodipine 5mg",
            improvement: "Vitals stable for 30 consecutive days"
        },
        history: [
            { date: "2026-01-25", hr: 70, bp: "120/80", notes: "Routine checkup." },
            { date: "2026-02-25", hr: 68, bp: "118/78", notes: "Excellent progress." }
        ],
        weeklySummary: "Exceptional stability over the last 7 days. All vital parameters (HR, BP, SpO2) are within optimal target ranges for age and profile. Patient is highly responsive to Amlodipine. No action required."
    },
    {
        id: "VS-0102",
        name: "Lata Mangeshkar",
        age: 61,
        gender: "Female",
        location: "Kolhapur",
        status: "critical",
        vitals: {
            hr: 125,
            bp: "160/100",
            spo2: 89,
            temp: 38.2
        },
        alerts: [
            "Possible Arrhythmia detected",
            "Low SpO2 alert (< 90%)"
        ],
        rxEfficacy: null,
        history: [
            { date: "2026-02-24", hr: 120, bp: "155/95", notes: "SpO2 dropping." },
            { date: "2026-02-26", hr: 125, bp: "160/100", notes: "Admitted to critical care." }
        ],
        weeklySummary: "Critical instability detected. Significant respiratory distress and high-grade tachycardia observed. SpO2 levels have dipped below 90% multiple times this week. Patient requires immediate specialist intervention and likely ICU admission."
    },
    {
        id: "VS-0134",
        name: "Anil Jawale",
        age: 45,
        gender: "Male",
        location: "Satara",
        status: "stable",
        vitals: {
            hr: 72,
            bp: "120/80",
            spo2: 99,
            temp: 36.4
        },
        alerts: [],
        rxEfficacy: null,
        history: [
            { date: "2026-02-10", hr: 75, bp: "122/82", notes: "Initial screening." },
            { date: "2026-02-27", hr: 72, bp: "120/80", notes: "Stable." }
        ],
        weeklySummary: "Maintaining good health status. Vitals are consistently stable without pharmacological intervention. Patient reports good activity levels. Recommended to continue routine monitoring."
    }
];
