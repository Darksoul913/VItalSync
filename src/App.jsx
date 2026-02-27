import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Sidebar from './components/layout/Sidebar';
import Dashboard from './components/Dashboard';
import PatientHistory from './components/dashboard/PatientHistory';
import './App.css';

function App() {
  return (
    <div className="layout">
      <Sidebar />
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/history/:id" element={<PatientHistory />} />
      </Routes>
    </div>
  );
}

export default App;
