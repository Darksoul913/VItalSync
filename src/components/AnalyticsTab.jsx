import React, { useState, useMemo } from 'react';
import Topbar from './layout/Topbar';
import StatsCard from './dashboard/StatsCard';
import { patientsData } from '../data/patients';

const AnalyticsTab = () => {
    const [searchTerm, setSearchTerm] = useState('');

    const stats = useMemo(() => {
        const total = patientsData.length;
        const critical = patientsData.filter(p => p.status === 'critical').length;
        const warning = patientsData.filter(p => p.status === 'warning').length;
        const stable = patientsData.filter(p => p.status === 'stable').length;

        const avgAge = Math.round(patientsData.reduce((acc, p) => acc + p.age, 0) / total);

        const males = patientsData.filter(p => p.gender === 'Male').length;
        const females = patientsData.filter(p => p.gender === 'Female').length;

        return { total, critical, warning, stable, avgAge, males, females };
    }, []);

    return (
        <main className="main-content">
            <Topbar searchTerm={searchTerm} onSearchChange={setSearchTerm} />

            <div className="dashboard-header">
                <div>
                    <h1>System Analytics</h1>
                    <p className="subtitle">Aggregated demographic and status metrics</p>
                </div>
            </div>

            <div className="stats-overview">
                <StatsCard
                    variant="blue"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>}
                    value={stats.total}
                    label="Total Population"
                />
                <StatsCard
                    variant="green"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>}
                    value={stats.avgAge}
                    label="Average Age"
                />
                <StatsCard
                    variant="alert"
                    icon={<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>}
                    value={stats.critical}
                    label="Critical Alerts"
                />
            </div>

            <div className="analytics-charts">
                <div className="chart-card">
                    <h3>Patient Status Distribution</h3>
                    <div className="bar-chart">
                        <div className="bar-group">
                            <div className="bar-label">Stable ({stats.stable})</div>
                            <div className="bar-track">
                                <div className="bar-fill good" style={{ width: `${(stats.stable / stats.total) * 100}%` }}></div>
                            </div>
                        </div>
                        <div className="bar-group">
                            <div className="bar-label">Warning ({stats.warning})</div>
                            <div className="bar-track">
                                <div className="bar-fill warning" style={{ width: `${(stats.warning / stats.total) * 100}%` }}></div>
                            </div>
                        </div>
                        <div className="bar-group">
                            <div className="bar-label">Critical ({stats.critical})</div>
                            <div className="bar-track">
                                <div className="bar-fill critical" style={{ width: `${(stats.critical / stats.total) * 100}%` }}></div>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="chart-card">
                    <h3>Demographics Breakdown</h3>
                    <div className="demographics-grid">
                        <div className="demo-box">
                            <div className="demo-icon">M</div>
                            <div className="demo-val">{stats.males}</div>
                            <div className="demo-label">Male</div>
                        </div>
                        <div className="demo-box">
                            <div className="demo-icon">F</div>
                            <div className="demo-val">{stats.females}</div>
                            <div className="demo-label">Female</div>
                        </div>
                    </div>
                </div>
            </div>
        </main>
    );
};

export default AnalyticsTab;
