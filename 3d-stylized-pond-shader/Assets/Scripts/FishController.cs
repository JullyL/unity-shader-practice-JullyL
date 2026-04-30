using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Autonomous koi controller.
///
/// Setup:
///   1. Attach to the fish GameObject.
///   2. Assign lilyPads (Transform array) in the Inspector.
///   3. Assign pondCenter (empty GameObject at pond centre).
///   4. Set obstacleLayer to whatever layer your lily pad colliders are on.
///   5. Water shader receives _FishWorldPos / _FishRippleStrength as Shader globals —
///      no material reference needed here.
/// </summary>
public class FishController : MonoBehaviour
{
    // ─────────────────── Swimming ────────────────────────────────
    [Header("Swimming")]
    public float swimSpeed       = 1.2f;
    public float turnSpeed       = 75f;   // degrees / second
    public float bobAmplitude    = 0.04f; // vertical surface dip
    public float bobFrequency    = 1.2f;
    [Tooltip("Side-to-side body rock in degrees — simulates tail wag without touching mesh vertices.")]
    public float bodyRockDegrees = 8f;
    [Tooltip("How many wags per second.")]
    public float bodyRockFrequency = 2.5f;

    // ─────────────────── Lily-pad patrol ─────────────────────────
    [Header("Patrol — Lily Pad Orbiting")]
    [Tooltip("Assign all lily pad root transforms here.")]
    public Transform[] lilyPads;
    [Tooltip("Leave empty to auto-find objects tagged 'LilyPad'.")]
    public string lilyPadTag     = "LilyPad";
    public float  orbitRadius    = 1.4f;
    [Range(3, 8)]
    public int    waypointsPerPad = 5;
    public float  waypointReachRadius = 0.4f;

    // ─────────────────── Obstacle avoidance ──────────────────────
    [Header("Obstacle Avoidance")]
    public LayerMask obstacleLayer;
    public float detectDistance  = 1.8f;
    [Range(10f, 60f)]
    public float avoidFanAngle   = 40f;   // half-angle of the 5-ray fan
    public float avoidWeight     = 2.5f;

    // ─────────────────── Pond boundary ───────────────────────────
    [Header("Pond Boundary")]
    public Transform pondCenter;
    public float pondRadius      = 7f;
    public float boundaryZone    = 1.5f;  // soft-push width inside boundary

    // ─────────────────── Ripple (water shader) ───────────────────
    [Header("Water Ripple")]
    [Range(0f, 1f)]
    public float rippleStrength  = 0.6f;

    // ─────────────────── Private state ───────────────────────────
    List<Vector3> _waypoints = new();
    int   _wpIndex;
    float _bobPhase;
    float _baseY;

    // Cached shader property IDs so we don't hash strings every frame
    static readonly int _FishWorldPosID      = Shader.PropertyToID("_FishWorldPos");
    static readonly int _FishRippleStrID     = Shader.PropertyToID("_FishRippleStrength");
    static readonly int _FishSwimSpeedID     = Shader.PropertyToID("_FishSwimSpeed");

    // ─────────────────────────────────────────────────────────────
    void Start()
    {
        _baseY = transform.position.y;
        ResolveLilyPads();
        GenerateWaypoints();
        _wpIndex = Random.Range(0, Mathf.Max(1, _waypoints.Count));
    }

    void Update()
    {
        if (_waypoints.Count == 0) return;

        Vector3 steering = ComputeSteering();
        ApplyMovement(steering);
        CheckWaypointReached();
        PushRippleToShader();
    }

    // ─────────────────── Lily-pad resolution ─────────────────────
    void ResolveLilyPads()
    {
        // If none assigned in Inspector, find by tag
        if (lilyPads == null || lilyPads.Length == 0)
        {
            var found = GameObject.FindGameObjectsWithTag(lilyPadTag);
            lilyPads = new Transform[found.Length];
            for (int i = 0; i < found.Length; i++)
                lilyPads[i] = found[i].transform;
        }
    }

    // ─────────────────── Waypoint generation ─────────────────────
    void GenerateWaypoints()
    {
        _waypoints.Clear();

        if (lilyPads.Length == 0)
        {
            // No lily pads: patrol random points within the pond
            for (int i = 0; i < 8; i++)
            {
                float a = i / 8f * Mathf.PI * 2f;
                float r = pondRadius * 0.55f;
                Vector3 pt = (pondCenter != null ? pondCenter.position : Vector3.zero)
                           + new Vector3(Mathf.Cos(a) * r, 0f, Mathf.Sin(a) * r);
                pt.y = _baseY;
                _waypoints.Add(pt);
            }
            return;
        }

        foreach (var pad in lilyPads)
        {
            if (pad == null) continue;
            for (int i = 0; i < waypointsPerPad; i++)
            {
                float angle = i * (360f / waypointsPerPad) * Mathf.Deg2Rad;
                Vector3 offset = new Vector3(Mathf.Cos(angle), 0f, Mathf.Sin(angle)) * orbitRadius;
                Vector3 wp = pad.position + offset;
                wp.y = _baseY;
                _waypoints.Add(wp);
            }
        }

        // Shuffle so multiple fish don't follow the same path
        for (int i = _waypoints.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            (_waypoints[i], _waypoints[j]) = (_waypoints[j], _waypoints[i]);
        }
    }

    // ─────────────────── Steering ────────────────────────────────
    Vector3 ComputeSteering()
    {
        Vector3 toWaypoint = _waypoints[_wpIndex] - transform.position;
        toWaypoint.y = 0f;
        Vector3 desired = toWaypoint.normalized;

        Vector3 avoid    = ComputeAvoidanceForce();
        Vector3 boundary = ComputeBoundaryForce();

        float avoidMag = avoid.magnitude;
        Vector3 combined = desired
                         + avoid    * (avoidWeight * Mathf.Clamp01(avoidMag))
                         + boundary * 1.8f;

        combined.y = 0f;
        return combined == Vector3.zero ? transform.forward : combined.normalized;
    }

    // 5-ray fan: straight ahead, ±half-angle, ±full-angle
    Vector3 ComputeAvoidanceForce()
    {
        Vector3 sum = Vector3.zero;
        float[] angles = { 0f, -avoidFanAngle * 0.5f, avoidFanAngle * 0.5f,
                                -avoidFanAngle,          avoidFanAngle };
        foreach (float a in angles)
        {
            Vector3 dir = Quaternion.Euler(0f, a, 0f) * transform.forward;
            if (Physics.Raycast(transform.position, dir, out RaycastHit hit,
                                detectDistance, obstacleLayer))
            {
                float weight = 1f - (hit.distance / detectDistance);
                Vector3 away = transform.position - hit.point;
                away.y = 0f;
                sum += away.normalized * weight;
            }
        }
        return sum;
    }

    Vector3 ComputeBoundaryForce()
    {
        if (pondCenter == null) return Vector3.zero;
        Vector3 toCenter = pondCenter.position - transform.position;
        toCenter.y = 0f;
        float dist = toCenter.magnitude;
        float inner = pondRadius - boundaryZone;
        if (dist > inner)
        {
            float t = Mathf.InverseLerp(inner, pondRadius, dist);
            return toCenter.normalized * t;
        }
        return Vector3.zero;
    }

    // ─────────────────── Movement ────────────────────────────────
    void ApplyMovement(Vector3 steeringDir)
    {
        if (steeringDir.sqrMagnitude > 0.001f)
        {
            Quaternion target = Quaternion.LookRotation(steeringDir, Vector3.up);
            transform.rotation = Quaternion.RotateTowards(transform.rotation, target,
                                                          turnSpeed * Time.deltaTime);
        }

        transform.position += transform.forward * swimSpeed * Time.deltaTime;

        // Vertical bob — fish gently dips at the water surface
        _bobPhase += bobFrequency * Time.deltaTime;
        float y = _baseY + Mathf.Sin(_bobPhase * Mathf.PI * 2f) * bobAmplitude;
        transform.position = new Vector3(transform.position.x, y, transform.position.z);

        // Body rock: oscillate the whole fish around Y to mimic a tail wag.
        // Applied on top of the steering rotation so it doesn't fight turning.
        float rock = Mathf.Sin(Time.time * bodyRockFrequency * Mathf.PI * 2f) * bodyRockDegrees;
        transform.rotation *= Quaternion.Euler(0f, rock * Time.deltaTime * 6f, 0f);
    }

    void CheckWaypointReached()
    {
        Vector3 flat = _waypoints[_wpIndex];
        flat.y = transform.position.y;
        if (Vector3.Distance(transform.position, flat) < waypointReachRadius)
            _wpIndex = (_wpIndex + 1) % _waypoints.Count;
    }

    // ─────────────────── Shader feedback (ripple) ────────────────
    void PushRippleToShader()
    {
        // Water shader reads these as Shader globals — no material ref required
        Shader.SetGlobalVector(_FishWorldPosID,  transform.position);
        Shader.SetGlobalFloat(_FishRippleStrID,  rippleStrength);
        Shader.SetGlobalFloat(_FishSwimSpeedID,  swimSpeed);
    }

    // ─────────────────── Gizmos ──────────────────────────────────
#if UNITY_EDITOR
    void OnDrawGizmosSelected()
    {
        // Pond boundary rings
        if (pondCenter != null)
        {
            Gizmos.color = new Color(0.2f, 0.8f, 0.9f, 0.35f);
            DrawCircle(pondCenter.position, pondRadius);
            Gizmos.color = new Color(1f, 0.5f, 0.2f, 0.25f);
            DrawCircle(pondCenter.position, pondRadius - boundaryZone);
        }

        // Patrol waypoints
        Gizmos.color = Color.yellow;
        for (int i = 0; i < _waypoints.Count; i++)
        {
            Gizmos.DrawSphere(_waypoints[i], 0.07f);
            Gizmos.DrawLine(_waypoints[i], _waypoints[(i + 1) % _waypoints.Count]);
        }
        if (_waypoints.Count > 0 && _wpIndex < _waypoints.Count)
        {
            Gizmos.color = Color.cyan;
            Gizmos.DrawSphere(_waypoints[_wpIndex], 0.12f);
        }

        // Avoidance rays (play mode only)
        if (Application.isPlaying)
        {
            Gizmos.color = Color.red;
            float[] angles = { 0f, -avoidFanAngle * 0.5f, avoidFanAngle * 0.5f,
                                    -avoidFanAngle,          avoidFanAngle };
            foreach (float a in angles)
            {
                Vector3 dir = Quaternion.Euler(0f, a, 0f) * transform.forward;
                Gizmos.DrawRay(transform.position, dir * detectDistance);
            }
        }
    }

    void DrawCircle(Vector3 center, float radius)
    {
        const int segs = 32;
        Vector3 prev = center + new Vector3(radius, 0f, 0f);
        for (int i = 1; i <= segs; i++)
        {
            float a = i / (float)segs * Mathf.PI * 2f;
            Vector3 next = center + new Vector3(Mathf.Cos(a) * radius, 0f, Mathf.Sin(a) * radius);
            Gizmos.DrawLine(prev, next);
            prev = next;
        }
    }
#endif
}
