<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Modules\Destination\Services\DestinationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DestinationController extends Controller
{
    public function __construct(
        private readonly DestinationService $service,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $bbox = null;
        if ($request->has('bbox') && $request->input('bbox') !== null && $request->input('bbox') !== '') {
            $parts = explode(',', (string) $request->input('bbox'));
            if (count($parts) === 4 && collect($parts)->every(fn ($v) => is_numeric($v))) {
                $bbox = array_map('floatval', $parts);
            }
        }

        $destinations = $this->service->list($bbox);

        return response()->json(['destinations' => $destinations], 200);
    }
}
