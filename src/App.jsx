import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Sidebar from './components/layout/Sidebar';
import Dashboard from './components/Dashboard';
import PatientsTab from './components/PatientsTab';
import AnalyticsTab from './components/AnalyticsTab';
import PatientHistory from './components/dashboard/PatientHistory';
import './App.css';

function App() {
  return (
    <div className="layout">
      <Sidebar />
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/patients" element={<PatientsTab />} />
        <Route path="/analytics" element={<AnalyticsTab />} />
        <Route path="/history/:id" element={<PatientHistory />} />
      </Routes>
    </div>
  );
}

export default App;
