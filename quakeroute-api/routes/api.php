<?php

use App\Http\Controllers\Api\V1\DestinationController;
use App\Http\Controllers\Api\V1\HazardController;
use App\Http\Controllers\Api\V1\HazardReportController;
use App\Http\Controllers\Api\V1\HazardSuggestionController;
use App\Http\Controllers\Api\V1\RoadSegmentController;
use App\Http\Controllers\Api\V1\RouteController;
use App\Http\Controllers\Api\V1\SimulationController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Hazard Reporting
    Route::post('/hazard-reports/photo', [HazardReportController::class, 'photo']);
    Route::post('/hazard-reports/text', [HazardReportController::class, 'text']);
    Route::post('/hazard-reports/quick', [HazardReportController::class, 'quick']);
    Route::post('/hazard-reports/voice', [HazardReportController::class, 'voice']);

    Route::post('/hazard-suggestions/{suggestion_id}/confirm', [HazardSuggestionController::class, 'confirm']);
    Route::post('/hazard-suggestions/{suggestion_id}/reject', [HazardSuggestionController::class, 'reject']);

    // Hazard Retrieval
    Route::get('/hazards', [HazardController::class, 'index']);
    Route::get('/hazards/{hazard_id}', [HazardController::class, 'show']);

    // Destinations
    Route::get('/destinations', [DestinationController::class, 'index']);

    // Road Segments (Dynamic Safety Map — road network geometry)
    Route::get('/road-segments', [RoadSegmentController::class, 'index']);

    // Routing
    Route::post('/routes', [RouteController::class, 'store']);
    Route::get('/routes/active', [RouteController::class, 'active']);
    Route::get('/routes/{route_id}', [RouteController::class, 'show']);

    // Simulation
    Route::get('/simulation/scenarios', [SimulationController::class, 'scenarios']);
    Route::post('/simulation/scenarios/{scenario_id}/run', [SimulationController::class, 'run']);
    Route::get('/simulation/runs/{run_id}', [SimulationController::class, 'show']);
});
