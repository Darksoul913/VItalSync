import React from 'react';
import { Link } from 'react-router-dom';

const DetailPanel = ({ patient, isOpen, onClose }) => {
    if (!patient) return null;

    return (
        <>
            <aside className={`detail-panel ${isOpen ? 'open' : ''}`}>
                <div className="panel-header">
                    <h3>Patient File</h3>
                    <button className="close-btn" onClick={onClose}>
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <line x1="18" y1="6" x2="6" y2="18"></line>
                            <line x1="6" y1="6" x2="18" y2="18"></line>
                        </svg>
                    </button>
                </div>
                <div className={`panel-content ${patient.status === 'critical' ? 'status-critical' : ''}`}>
                    <div className="patient-profile">
                        <div className="avatar-large">{patient.name.charAt(0)}</div>
                        <div>
                            <h2>{patient.name}</h2>
                            <div className="meta">{patient.id} • {patient.age} y/o • {patient.gender} • {patient.location}</div>
                        </div>
                    </div>

                    <div className={`status-badge ${patient.status}`} style={{ display: 'inline-block', marginBottom: '24px' }}>
                        Status: {patient.status}
                    </div>

                    <h4 className="section-title">Live Vitals</h4>
                    <div className="vitals-grid">
                        <div className="vital-box">
                            <div className="label">Heart Rate</div>
                            <div className="val-row">
                                <span className={`val ${patient.status === 'critical' && patient.vitals.hr > 100 ? 'text-red' : ''}`}>{patient.vitals.hr}</span>
                                <span className="unit">BPM</span>
                            </div>
                        </div>
                        <div className="vital-box">
                            <div className="label">Blood Pressure (PTT)</div>
                            <div className="val-row">
                                <span className="val">{patient.vitals.bp}</span>
                                <span className="unit">mmHg</span>
                            </div>
                        </div>
                        <div className="vital-box">
                            <div className="label">SpO2</div>
                            <div className="val-row">
                                <span className={`val ${patient.status === 'critical' && patient.vitals.spo2 < 95 ? 'text-red' : ''}`}>{patient.vitals.spo2}</span>
                                <span className="unit">%</span>
                            </div>
                        </div>
                        <div className="vital-box">
                            <div className="label">Temperature</div>
                            <div className="val-row">
                                <span className="val">{patient.vitals.temp}</span>
                                <span className="unit">°C</span>
                            </div>
                        </div>
                    </div>

                    <h4 className="section-title">Weekly Summary (Last 7 Days)</h4>
                    <div className="stat-card" style={{ padding: '20px', background: 'rgba(255,255,255,0.05)', borderRadius: 'var(--radius-sm)', border: '1px solid rgba(255,255,255,0.1)', marginBottom: '24px' }}>
                        <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                            <div style={{ color: 'var(--accent-blue)', marginTop: '2px' }}>
                                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                                    <polyline points="14 2 14 8 20 8"></polyline>
                                    <line x1="16" y1="13" x2="8" y2="13"></line>
                                    <line x1="16" y1="17" x2="8" y2="17"></line>
                                    <polyline points="10 9 9 9 8 9"></polyline>
                                </svg>
                            </div>
                            <div style={{ fontSize: '0.95rem', lineHeight: '1.6', color: 'var(--text-secondary)', fontStyle: 'italic' }}>
                                "{patient.weeklySummary || "No summary available for this week."}"
                            </div>
                        </div>
                    </div>

                    <h4 className="section-title">Live ECG Stream</h4>
                    <div className="ecg-card">
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '8px', display: 'flex', justifyContent: 'space-between' }}>
                            <span>Lead I (Simulated)</span>
                            <span style={{ color: 'var(--status-good)' }}>500Hz Sampling</span>
                        </div>
                        <div className="ecg-graph">
                            <svg viewBox="0 0 500 100" className="ecg-svg" preserveAspectRatio="none" style={{ width: '200%', height: '100%' }}>
                                <path d="M0,50 L50,50 L55,40 L60,60 L65,20 L75,90 L85,45 L95,55 L100,50 L150,50 L155,40 L160,60 L165,20 L175,90 L185,45 L195,55 L200,50 L250,50 L255,40 L260,60 L265,20 L275,90 L285,45 L295,55 L300,50 L350,50 L355,40 L360,60 L365,20 L375,90 L385,45 L395,55 L400,50 L450,50 L455,40 L460,60 L465,20 L475,90 L485,45 L495,55 L500,50"></path>
                            </svg>
                        </div>
                    </div>

                    {patient.alerts && patient.alerts.length > 0 && (
                        <div className="alert-box">
                            <h4>
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
                                Active Alerts
                            </h4>
                            {patient.alerts.map((a, i) => <p key={i}>• {a}</p>)}
                        </div>
                    )}

                    {patient.rxEfficacy && (
                        <>
                            <h4 className="section-title">Rx-Efficacy Engine</h4>
                            <div className="rx-efficacy">
                                <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Current Regimen</div>
                                <div style={{ fontWeight: 600, marginBottom: '8px' }}>{patient.rxEfficacy.medication}</div>
                                <div className="rx-stat">
                                    <span>Outcome:</span>
                                    <span className="positive">
                                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline><polyline points="17 6 23 6 23 12"></polyline></svg>
                                        {patient.rxEfficacy.improvement}
                                    </span>
                                </div>
                            </div>
                        </>
                    )}

                    <div style={{ marginTop: '32px', display: 'flex', gap: '12px' }}>
                        <button style={{ flex: 1, padding: '12px', background: 'var(--accent-blue)', color: '#000', border: 'none', borderRadius: 'var(--radius-sm)', fontWeight: 600, cursor: 'pointer', transition: '0.2s' }}>
                            Contact Patient
                        </button>
                        <Link
                            to={`/history/${patient.id}`}
                            onClick={onClose}
                            style={{ flex: 1, padding: '12px', background: 'rgba(255,255,255,0.1)', color: '#fff', border: '1px solid rgba(255,255,255,0.2)', borderRadius: 'var(--radius-sm)', fontWeight: 600, cursor: 'pointer', transition: '0.2s', textAlign: 'center', textDecoration: 'none' }}
                        >
                            View Full History
                        </Link>
                    </div>
                </div>
            </aside>
            <div className={`overlay ${isOpen ? 'show' : ''}`} onClick={onClose}></div>
        </>
    );
};

export default DetailPanel;
