<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SimulationRunRequest;
use App\Modules\Simulation\Services\SimulationService;
use Illuminate\Http\JsonResponse;

class SimulationController extends Controller
{
    public function __construct(
        private readonly SimulationService $service,
    ) {}

    public function scenarios(): JsonResponse
    {
        $scenarios = $this->service->listScenarios();

        return response()->json(['scenarios' => $scenarios], 200);
    }

    public function run(SimulationRunRequest $request, string $scenario_id): JsonResponse
    {
        $result = $this->service->runScenario($scenario_id, $request->input('origin'), $request->input('destination_id'));

        return response()->json($result, 202);
    }

    public function show(string $run_id): JsonResponse
    {
        $result = $this->service->getRun($run_id);

        return response()->json($result, 200);
    }
}
