<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ConfirmSuggestionRequest;
use App\Modules\Hazard\Services\HazardSuggestionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HazardSuggestionController extends Controller
{
    public function __construct(
        private readonly HazardSuggestionService $service,
    ) {}

    public function confirm(ConfirmSuggestionRequest $request, string $suggestion_id): JsonResponse
    {
        $result = $this->service->confirm($suggestion_id, $request->input('edits'));

        return response()->json($result, 200);
    }

    public function reject(Request $request, string $suggestion_id): JsonResponse
    {
        $result = $this->service->reject($suggestion_id);

        return response()->json($result, 200);
    }
}
