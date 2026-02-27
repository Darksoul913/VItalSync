import React, { useState } from 'react';
import Topbar from './layout/Topbar';
import { patientsData } from '../data/patients';

const PatientsTab = () => {
    const [searchTerm, setSearchTerm] = useState('');

    const filteredPatients = patientsData.filter(patient => 
        patient.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        patient.id.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <main className="main-content">
            <Topbar searchTerm={searchTerm} onSearchChange={setSearchTerm} />

            <div className="dashboard-header">
                <div>
                    <h1>Patients Directory</h1>
                    <p className="subtitle">Comprehensive list of all monitored patients</p>
                </div>
            </div>

            <div className="patients-table-container">
                <table className="patients-table">
                    <thead>
                        <tr>
                            <th>Patient ID</th>
                            <th>Name</th>
                            <th>Age/Gender</th>
                            <th>Location</th>
                            <th>Status</th>
                            <th>Latest HR</th>
                            <th>Latest BP</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredPatients.map(patient => (
                            <tr key={patient.id}>
                                <td className="id-col">{patient.id}</td>
                                <td className="name-col">{patient.name}</td>
                                <td>{patient.age} / {patient.gender.charAt(0)}</td>
                                <td>{patient.location}</td>
                                <td>
                                    <span className={`status-badge ${patient.status}`}>
                                        {patient.status}
                                    </span>
                                </td>
                                <td className={patient.vitals.hr > 100 || patient.vitals.hr < 60 ? 'text-red' : ''}>
                                    {patient.vitals.hr} bpm
                                </td>
                                <td>{patient.vitals.bp}</td>
                            </tr>
                        ))}
                        {filteredPatients.length === 0 && (
                            <tr>
                                <td colSpan="7" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                                    No patients found.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </main>
    );
};

export default PatientsTab;
