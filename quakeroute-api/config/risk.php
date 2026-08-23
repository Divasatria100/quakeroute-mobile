<?php

/*
|--------------------------------------------------------------------------
| MVP Risk Calibration Baseline
|--------------------------------------------------------------------------
|
| These values are MVP calibration assumptions, not empirically validated
| real-world safety weights. They are config-driven and may be recalibrated
| during Phase 8 Validation.
|
| Do not claim these values are scientifically optimal.
|
*/

return [
    'severity_weights' => [
        'Low' => (float) env('RISK_SEVERITY_LOW', 10),
        'Medium' => (float) env('RISK_SEVERITY_MEDIUM', 30),
        'High' => (float) env('RISK_SEVERITY_HIGH', 100),
    ],

    'confidence' => [
        'mode' => env('RISK_CONFIDENCE_MODE', 'linear'),
    ],

    'uncertainty_weights' => [
        'Reported' => (float) env('RISK_UNCERTAINTY_REPORTED', 5),
        'Confirmed' => (float) env('RISK_UNCERTAINTY_CONFIRMED', 0),
        'UncertainConflicting' => (float) env('RISK_UNCERTAINTY_CONFLICTING', 20),
    ],

    'blocked_cost' => env('RISK_BLOCKED_COST', PHP_INT_MAX),
];
