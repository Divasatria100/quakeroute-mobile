<?php
// temp manual simulation runner
$svc = app(\App\Modules\Simulation\Services\SimulationService::class);
$res = $svc->runScenario('blocked_road', ['lat' => -6.2001, 'lng' => 106.8001], 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3');
echo json_encode($res, JSON_PRETTY_PRINT), "\n";
$run = $svc->getRun($res['run_id']);
echo json_encode($run, JSON_PRETTY_PRINT), "\n";