import React from 'react';

const PatientCard = ({ patient, onClick }) => {
    return (
        <div className="patient-card" data-status={patient.status} onClick={() => onClick(patient)}>
            <div className="patient-header">
                <div className="patient-info">
                    <h3>{patient.name}</h3>
                    <span className="id">{patient.id} • {patient.age}yo {patient.gender.charAt(0)}</span>
                </div>
                <div className={`status-badge ${patient.status}`}>
                    {patient.status}
                </div>
            </div>

            <div className="vitals-mini">
                <div className="vital">
                    <span className="vital-label">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--status-critical)" strokeWidth="2">
                            <path d="M20.42 4.58a5.4 5.4 0 0 0-7.65 0l-.77.78-.77-.78a5.4 5.4 0 0 0-7.65 0C1.46 6.7 1.33 10.28 4 13l8 8 8-8c2.67-2.72 2.54-6.3.42-8.42z"></path>
                        </svg>
                        HR
                    </span>
                    <span className={`vital-val ${patient.status === 'critical' && patient.vitals.hr > 100 ? 'text-red' : ''}`}>
                        {patient.vitals.hr} <span className="unit">bpm</span>
                    </span>
                </div>
                <div className="vital">
                    <span className="vital-label">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--accent-blue)" strokeWidth="2">
                            <path d="M12 2v20"></path>
                            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
                        </svg>
                        BP
                    </span>
                    <span className="vital-val">{patient.vitals.bp} <span className="unit">mmHg</span></span>
                </div>
                <div className="vital">
                    <span className="vital-label">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--status-good)" strokeWidth="2">
                            <circle cx="12" cy="12" r="10"></circle>
                            <path d="M8 14s1.5 2 4 2 4-2 4-2"></path>
                            <line x1="9" y1="9" x2="9.01" y2="9"></line>
                            <line x1="15" y1="9" x2="15.01" y2="9"></line>
                        </svg>
                        SpO2
                    </span>
                    <span className={`vital-val ${patient.status === 'critical' && patient.vitals.spo2 < 95 ? 'text-red' : ''}`}>
                        {patient.vitals.spo2} <span className="unit">%</span>
                    </span>
                </div>
            </div>
        </div>
    );
};

export default PatientCard;
