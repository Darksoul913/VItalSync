import React, { useState, useMemo } from 'react';
import Topbar from './layout/Topbar';
import StatsCard from './dashboard/StatsCard';
import PatientCard from './dashboard/PatientCard';
import DetailPanel from './dashboard/DetailPanel';
import { patientsData } from '../data/patients';

const Dashboard = () => {
    const [searchTerm, setSearchTerm] = useState('');
    const [filter, setFilter] = useState('all');
    const [selectedPatient, setSelectedPatient] = useState(null);
    const [isPanelOpen, setIsPanelOpen] = useState(false);

    // Statistics calculations
    const stats = useMemo(() => {
        const total = patientsData.length;
        const critical = patientsData.filter(p => p.status === 'critical').length;
        return { total, critical, active: total };
    }, []);

    // Filter and search logic
    const filteredPatients = useMemo(() => {
        return patientsData.filter(patient => {
            const matchesSearch = patient.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                patient.id.toLowerCase().includes(searchTerm.toLowerCase());
            const matchesFilter = filter === 'all' || patient.status === filter;
            return matchesSearch && matchesFilter;
        });
    }, [searchTerm, filter]);

    const handlePatientClick = (patient) => {
        setSelectedPatient(patient);
        setIsPanelOpen(true);
        document.body.style.overflow = 'hidden';
    };

    const handleClosePanel = () => {
        setIsPanelOpen(false);
        document.body.style.overflow = '';
    };

    const handleSearchChange = (term) => {
        setSearchTerm(term);
        setFilter('all'); // Reset filter when searching
    };

    return (
        <main className="main-content">
            <Topbar searchTerm={searchTerm} onSearchChange={handleSearchChange} />

            <div className="dashboard-header">
                <div>
                    <h1>Patient Overview</h1>
                    <p className="subtitle">Real-time remote vital monitoring</p>
                </div>
                <div className="filters">
                    <button
                        className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
                        onClick={() => setFilter('all')}
                    >
                        All Patients
                    </button>
                    <button
                        className={`filter-btn alert ${filter === 'critical' ? 'active' : ''}`}
                        onClick={() => setFilter('critical')}
                    >
                        Status: Critical
                    </button>
                    <button
                        className={`filter-btn warning ${filter === 'warning' ? 'active' : ''}`}
                        onClick={() => setFilter('warning')}
                    >
                        Status: Warning
                    </button>
                    <button
                        className={`filter-btn good ${filter === 'stable' ? 'active' : ''}`}
                        onClick={() => setFilter('stable')}
                    >
                        Status: Stable
                    </button>
                </div>
            </div>

            <div className="stats-overview">
                <StatsCard
                    variant="blue"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>}
                    value={stats.total}
                    label="Total Patients"
                />
                <StatsCard
                    variant="alert"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>}
                    value={stats.critical}
                    label="Critical Alerts"
                />
                <StatsCard
                    variant="green"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline></svg>}
                    value={stats.active}
                    label="Active Monitoring"
                />
            </div>

            <div className="patient-grid">
                {filteredPatients.length > 0 ? (
                    filteredPatients.map(patient => (
                        <PatientCard
                            key={patient.id}
                            patient={patient}
                            onClick={handlePatientClick}
                        />
                    ))
                ) : (
                    <div style={{ color: 'var(--text-secondary)', gridColumn: '1/-1', textAlign: 'center', padding: '40px' }}>
                        No patients found matching criteria.
                    </div>
                )}
            </div>

            <DetailPanel
                patient={selectedPatient}
                isOpen={isPanelOpen}
                onClose={handleClosePanel}
            />
        </main>
    );
};

export default Dashboard;
