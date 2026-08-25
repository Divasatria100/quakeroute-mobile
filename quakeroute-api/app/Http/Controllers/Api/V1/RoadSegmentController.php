<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Modules\Road\Services\RoadSegmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RoadSegmentController extends Controller
{
    public function __construct(private readonly RoadSegmentService $service) {}

    public function index(Request $request): JsonResponse
    {
        $bbox = null;
        if ($request->has('bbox') && $request->input('bbox') !== null && $request->input('bbox') !== '') {
            $parts = explode(',', (string) $request->input('bbox'));
            if (count($parts) === 4 && collect($parts)->every(fn ($v) => is_numeric($v))) {
                $bbox = array_map('floatval', $parts);
            } else {
                return response()->json(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'Invalid bbox format']], 400);
            }
        }

        $data = $this->service->list($bbox);

        return response()->json(['data' => $data], 200);
    }
}
