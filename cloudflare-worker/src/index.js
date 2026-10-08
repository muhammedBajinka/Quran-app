import { deleteMedia } from "./delete-media.mjs";

function getAccessToken(request) {
  const authorization = request.headers.get("Authorization");

  if (!authorization || !authorization.startsWith("Bearer ")) {
    return null;
  }

  const accessToken = authorization.slice("Bearer ".length).trim();

  return accessToken || null;
}

async function getAuthenticatedUser(request, env) {
  const accessToken = getAccessToken(request);

  if (!accessToken) {
    return null;
  }

  const response = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: env.SUPABASE_PUBLISHABLE_KEY,
    },
  });

  if (!response.ok) {
    return null;
  }

  const user = await response.json();

  if (!user?.id) {
    return null;
  }

  return user;
}

async function createCreatorMedia(env, accessToken, media) {
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/rpc/create_creator_media`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: env.SUPABASE_PUBLISHABLE_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_id: media.id,
        p_content_type: media.contentType,
        p_title: media.title,
        p_description: media.description,
        p_media_type: media.mediaType,
        p_media_url: media.mediaUrl,
        p_speaker: media.speaker,
        p_thumbnail_url: media.thumbnailUrl,
        p_visibility: media.visibility,
      }),
    },
  );

  if (!response.ok) {
    const errorText = await response.text();

    throw new Error(
      `Failed to create media record (${response.status}): ${errorText}`,
    );
  }

  return response.json();
}

const allowedContentTypes = new Set([
  "dua",
  "sermon",
  "recitation",
  "other",
]);

const allowedMediaTypes = new Set([
  "audio",
  "video",
]);

const allowedMimeTypes = new Map([
  ["audio/mpeg", "mp3"],
  ["audio/mp4", "m4a"],
  ["audio/x-m4a", "m4a"],
  ["video/mp4", "mp4"],
  ["audio/webm", "webm"],
  ["video/webm", "webm"],
]);

const publicMediaBaseUrl =
  "https://pub-eeb6a67046c4422baecb5321c3b21655.r2.dev";

const allowedOrigins = new Set([
  "https://muhammedbajinka.github.io",
]);

function corsHeaders(request) {
  const origin = request.headers.get("Origin");

  if (!origin || !allowedOrigins.has(origin)) {
    return {};
  }

  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": [
      "Authorization",
      "Content-Type",
      "Accept",
      "X-Content-Type",
      "X-Media-Type",
      "X-Title",
      "X-Description",
      "X-Speaker",
    ].join(", "),
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function jsonResponse(request, body, init = {}) {
  const headers = new Headers(init.headers);

  for (const [name, value] of Object.entries(corsHeaders(request))) {
    headers.set(name, value);
  }

  headers.set("Content-Type", "application/json; charset=UTF-8");

  return new Response(JSON.stringify(body), {
    ...init,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      const origin = request.headers.get("Origin");

      if (!origin || !allowedOrigins.has(origin)) {
        return new Response(null, { status: 403 });
      }

      return new Response(null, {
        status: 204,
        headers: corsHeaders(request),
      });
    }

    if (request.method === "DELETE" && url.pathname.startsWith("/media/")) {
      try {
        const response = await deleteMedia(request, {
          ...env,
          MEDIA_PUBLIC_BASE_URL: publicMediaBaseUrl,
        });
        if (!response) {
          return jsonResponse(request, { error: "Invalid media ID" }, { status: 400 });
        }
        return jsonResponse(request, await response.json(), { status: response.status });
      } catch (error) {
        console.error("[DELETE] Failed:", error);
        return jsonResponse(request, { error: "Deletion could not finish. Retry from your profile." }, { status: 502 });
      }
    }

    if (url.pathname === "/health") {
      return jsonResponse(request, {
        ok: true,
        service: "quran-media-worker",
      });
    }

    if (url.pathname === "/r2-test") {
      try {
        const objects = await env.QURAN_MEDIA.list({ limit: 1 });

        return jsonResponse(request, {
          ok: true,
          bucketConnected: true,
          objectCountReturned: objects.objects.length,
        });
      } catch (error) {
        return jsonResponse(request, 
          {
            ok: false,
            bucketConnected: false,
            error: String(error),
          },
          { status: 500 },
        );
      }
    }

    if (url.pathname === "/upload" && request.method === "POST") {
      let objectKey = null;

      try {
        const accessToken = getAccessToken(request);
        const user = await getAuthenticatedUser(request, env);

        if (!accessToken || !user) {
          return jsonResponse(
            request,
            { ok: false, error: "Unauthorized" },
            { status: 401 },
          );
        }

        if (user.is_anonymous === true) {
          return jsonResponse(
            request,
            {
              ok: false,
              error: "A Google or other real account is required to upload.",
            },
            { status: 403 },
          );
        }

        const contentType = request.headers
          .get("X-Content-Type")
          ?.trim()
          .toLowerCase();

        const mediaType = request.headers
          .get("X-Media-Type")
          ?.trim()
          .toLowerCase();

        const title = request.headers.get("X-Title")?.trim();
        const description = request.headers.get("X-Description")?.trim() || null;
        const speaker = request.headers.get("X-Speaker")?.trim() || null;

        const mimeType = request.headers
          .get("Content-Type")
          ?.split(";")[0]
          .trim()
          .toLowerCase();

        if (!contentType || !allowedContentTypes.has(contentType)) {
          return jsonResponse(
            request,
            { ok: false, error: "Invalid content type." },
            { status: 400 },
          );
        }

        if (!mediaType || !allowedMediaTypes.has(mediaType)) {
          return jsonResponse(
            request,
            { ok: false, error: "Invalid media type." },
            { status: 400 },
          );
        }

        if (!title) {
          return jsonResponse(
            request,
            { ok: false, error: "Title is required." },
            { status: 400 },
          );
        }

        if (!mimeType || !allowedMimeTypes.has(mimeType)) {
          return jsonResponse(
            request,
            { ok: false, error: "Unsupported media format." },
            { status: 415 },
          );
        }

        if (
          (mediaType === "audio" && !mimeType.startsWith("audio/")) ||
          (mediaType === "video" && !mimeType.startsWith("video/"))
        ) {
          return jsonResponse(
            request,
            { ok: false, error: "Media type does not match the uploaded file." },
            { status: 400 },
          );
        }

        if (!request.body) {
          return jsonResponse(
            request,
            { ok: false, error: "Media file is required." },
            { status: 400 },
          );
        }

        const mediaId = crypto.randomUUID();
        const extension = allowedMimeTypes.get(mimeType);

        objectKey =
          `media/${user.id}/${mediaId}/original.${extension}`;

        await env.QURAN_MEDIA.put(objectKey, request.body, {
          httpMetadata: {
            contentType: mimeType,
          },
          customMetadata: {
            creatorId: user.id,
            mediaId,
          },
        });

        const mediaUrl =
          `${publicMediaBaseUrl}/${objectKey
            .split("/")
            .map(encodeURIComponent)
            .join("/")}`;

        const mediaRecord = await createCreatorMedia(
          env,
          accessToken,
          {
            id: mediaId,
            contentType,
            title,
            description,
            mediaType,
            mediaUrl,
            speaker,
            thumbnailUrl: null,
            visibility: "public",
          },
        );

        return jsonResponse(
          request,
          {
            ok: true,
            mediaId,
            mediaUrl,
            media: mediaRecord,
          },
          { status: 201 },
        );
      } catch (error) {
        console.error("[UPLOAD] Failed:", error);

        if (objectKey) {
          try {
            await env.QURAN_MEDIA.delete(objectKey);
          } catch {
            // Preserve the original upload error.
          }
        }

        return jsonResponse(
          request,
          {
            ok: false,
            error: "Upload failed.",
          },
          { status: 500 },
        );
      }
    }

    if (url.pathname === "/auth-test") {
      try {
        const user = await getAuthenticatedUser(request, env);

        if (!user) {
          return jsonResponse(request, 
            {
              ok: false,
              error: "Unauthorized",
            },
            { status: 401 },
          );
        }

        return jsonResponse(request, {
          ok: true,
          authenticated: true,
          userId: user.id,
          isAnonymous: user.is_anonymous === true,
        });
      } catch (error) {
        return jsonResponse(request,
          {
            ok: false,
            error: "Authentication check failed",
          },
          { status: 500 },
        );
      }
    }

    return new Response("Quran Media Worker", {
      status: 200,
    });
  },
};
