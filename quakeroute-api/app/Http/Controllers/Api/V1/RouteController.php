<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\RouteRequest;
use App\Modules\Route\Services\RouteService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RouteController extends Controller
{
    public function __construct(
        private readonly RouteService $routeService,
    ) {}

    public function store(RouteRequest $request): JsonResponse
    {
        $result = $this->routeService->createRoute($request, $request->input('destination_id'), $request->input('origin'));

        return response()->json($result, 201);
    }

    public function show(string $route_id): JsonResponse
    {
        $result = $this->routeService->getRoute($route_id);

        return response()->json($result, 200);
    }

    public function active(Request $request): JsonResponse
    {
        $result = $this->routeService->getActiveRoute($request);

        return response()->json($result, 200);
    }
}
