<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Modules\Hazard\Services\HazardQueryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HazardController extends Controller
{
    public function __construct(
        private readonly HazardQueryService $queryService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $bbox = null;
        if ($request->has('bbox') && $request->input('bbox') !== null && $request->input('bbox') !== '') {
            $parts = explode(',', (string) $request->input('bbox'));
            if (count($parts) !== 4 || ! collect($parts)->every(fn ($v) => is_numeric($v))) {
                return response()->json([
                    'error' => ['code' => 'VALIDATION_ERROR', 'message' => 'Invalid bbox', 'details' => []],
                ], 400);
            }
            $bbox = array_map('floatval', $parts);
        }

        $hazards = $this->queryService->list([
            'bbox' => $bbox,
            'status' => $request->input('status'),
            'updated_since' => $request->input('updated_since'),
        ]);

        return response()->json(['hazards' => $hazards], 200);
    }

    public function show(string $hazard_id): JsonResponse
    {
        $detail = $this->queryService->detail($hazard_id);

        return response()->json($detail, 200);
    }
}
