<?php

return [
    'provider' => env('AI_PROVIDER', ''),
    'api_key' => env('AI_API_KEY', ''),
    'model' => env('AI_MODEL', ''),
    'base_url' => env('AI_BASE_URL', ''),
    'timeout' => (int) env('AI_TIMEOUT', 15),
];
