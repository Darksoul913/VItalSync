import React from 'react';
import { useParams, Link } from 'react-router-dom';
import { patientsData } from '../../data/patients';

const PatientHistory = () => {
    const { id } = useParams();
    const patient = patientsData.find(p => p.id === id);

    if (!patient) {
        return (
            <div className="main-content" style={{ padding: '40px', textAlign: 'center' }}>
                <h2>Patient not found</h2>
                <Link to="/" className="filter-btn active" style={{ marginTop: '20px', display: 'inline-block', textDecoration: 'none' }}>
                    Back to Dashboard
                </Link>
            </div>
        );
    }

    return (
        <div className="main-content">
            <header className="topbar" style={{ justifyContent: 'flex-start', gap: '20px' }}>
                <Link to="/" className="action-btn" title="Back to Dashboard">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <line x1="19" y1="12" x2="5" y2="12"></line>
                        <polyline points="12 19 5 12 12 5"></polyline>
                    </svg>
                </Link>
                <h1>Medical History: {patient.name}</h1>
            </header>

            <div style={{ padding: '40px' }}>
                <div className="patient-profile" style={{ marginBottom: '40px' }}>
                    <div className="avatar-large">{patient.name.charAt(0)}</div>
                    <div>
                        <h2 style={{ fontSize: '2rem' }}>{patient.name}</h2>
                        <div className="meta" style={{ fontSize: '1.1rem' }}>
                            {patient.id} • {patient.age} y/o • {patient.gender} • {patient.location}
                        </div>
                        <div className={`status-badge ${patient.status}`} style={{ display: 'inline-block', marginTop: '12px' }}>
                            Current Status: {patient.status}
                        </div>
                    </div>
                </div>

                <h3 className="section-title">Historical Records</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                    {patient.history && patient.history.length > 0 ? (
                        patient.history.map((record, index) => (
                            <div key={index} className="stat-card" style={{ padding: '24px', display: 'block' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px', alignItems: 'center' }}>
                                    <span style={{ fontWeight: 700, fontSize: '1.2rem', color: 'var(--accent-blue)' }}>{record.date}</span>
                                    <div style={{ display: 'flex', gap: '20px' }}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>HR:</span>
                                            <span style={{ fontWeight: 600 }}>{record.hr} BPM</span>
                                        </div>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <span style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>BP:</span>
                                            <span style={{ fontWeight: 600 }}>{record.bp} mmHg</span>
                                        </div>
                                    </div>
                                </div>
                                <div style={{ color: 'var(--text-secondary)', fontSize: '1rem', borderTop: '1px solid var(--border-color)', paddingTop: '12px' }}>
                                    <strong>Notes:</strong> {record.notes}
                                </div>
                            </div>
                        ))
                    ) : (
                        <div className="stat-card" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                            No historical records found for this patient.
                        </div>
                    )}
                </div>

                <h3 className="section-title" style={{ marginTop: '40px' }}>Treatment Efficacy</h3>
                {patient.rxEfficacy ? (
                    <div className="rx-efficacy" style={{ padding: '24px' }}>
                        <div style={{ fontSize: '1rem', color: 'var(--text-secondary)', marginBottom: '8px' }}>Current Medication</div>
                        <div style={{ fontSize: '1.4rem', fontWeight: 700, marginBottom: '16px' }}>{patient.rxEfficacy.medication}</div>
                        <div className="rx-stat" style={{ fontSize: '1.1rem' }}>
                            <span>Outcome:</span>
                            <span className="positive" style={{ fontSize: '1.1rem' }}>
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline>
                                    <polyline points="17 6 23 6 23 12"></polyline>
                                </svg>
                                {patient.rxEfficacy.improvement}
                            </span>
                        </div>
                    </div>
                ) : (
                    <div className="stat-card" style={{ padding: '24px', color: 'var(--text-secondary)' }}>
                        No medication tracking data available.
                    </div>
                )}
            </div>
        </div>
    );
};

export default PatientHistory;
