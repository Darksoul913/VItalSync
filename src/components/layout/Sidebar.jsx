import React from 'react';
import { NavLink } from 'react-router-dom';

const Sidebar = () => {
    return (
        <aside className="sidebar">
            <div className="logo">
                <div className="logo-pulse"></div>
                <h2>VitalSync</h2>
            </div>
            <nav>
                <NavLink to="/" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`} end>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
                        <polyline points="9 22 9 12 15 12 15 22"></polyline>
                    </svg>
                    Dashboard
                </NavLink>
                <NavLink to="/patients" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                        <circle cx="9" cy="7" r="4"></circle>
                        <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                        <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
                    </svg>
                    Patients
                </NavLink>
                <NavLink to="/analytics" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
                    </svg>
                    Analytics
                </NavLink>
            </nav>
            <div className="doctor-profile">
                <img src="https://ui-avatars.com/api/?name=Dr+Smith&background=00F4FF&color=0B0F19&bold=true" alt="Dr. Smith" className="avatar" />
                <div className="doc-info">
                    <h4>Dr. A. Smith</h4>
                    <span>Cardiologist</span>
                </div>
            </div>
        </aside>
    );
};

export default Sidebar;
