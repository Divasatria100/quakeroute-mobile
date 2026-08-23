<?php

declare(strict_types=1);

namespace App\Modules\Shared\Support;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class SessionHelper
{
    public static function getOrCreateUserId(Request $request): ?string
    {
        $sessionId = $request->header('X-Session-Id');
        if (! is_string($sessionId) || $sessionId === '') {
            return null;
        }

        $user = DB::table('users')->where('session_id', $sessionId)->first();
        if ($user !== null) {
            DB::table('users')->where('id', $user->id)->update(['last_seen_at' => now()]);

            return $user->id;
        }

        $id = (string) Str::uuid();
        DB::table('users')->insert([
            'id' => $id,
            'session_id' => $sessionId,
            'device_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
            'last_seen_at' => now(),
        ]);

        return $id;
    }

    public static function getUserIdFromHeader(Request $request): ?string
    {
        $sessionId = $request->header('X-Session-Id');
        if (! is_string($sessionId) || $sessionId === '') {
            return null;
        }
        $user = DB::table('users')->where('session_id', $sessionId)->first();

        return $user?->id;
    }
}
