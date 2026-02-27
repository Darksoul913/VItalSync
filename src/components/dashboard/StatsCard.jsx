import React from 'react';

const StatsCard = ({ icon, value, label, variant = 'default' }) => {
    const isAlert = variant === 'alert';

    return (
        <div className={`stat-card ${isAlert ? 'alert-bg' : ''}`}>
            <div className={`stat-icon ${variant === 'blue' ? 'blue' : variant === 'red' ? 'red' : variant === 'green' ? 'green' : ''}`}>
                {icon}
            </div>
            <div className="stat-details">
                <span className={`stat-value ${isAlert ? 'text-red' : ''}`}>{value}</span>
                <span className="stat-label">{label}</span>
            </div>
        </div>
    );
};

export default StatsCard;
