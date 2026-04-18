use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

/// Simplified brief captured from a user conversation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BriefArtifact {
    pub title: String,
    pub problem_statement: String,
    pub target_audience: String,
    pub goals: Vec<String>,
    pub non_goals: Vec<String>,
    pub constraints: Vec<String>,
    pub success_metrics: Vec<String>,
    pub timeline_weeks: u32,
}

/// A single user story with acceptance criteria.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserStory {
    pub id: String,
    pub title: String,
    pub as_a: String,
    pub i_want: String,
    pub so_that: String,
    pub priority: Priority,
    pub acceptance_criteria: Vec<String>,
    pub story_points: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Priority {
    Critical,
    High,
    Medium,
    Low,
}

/// A section of functional requirements.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionalRequirement {
    pub id: String,
    pub section: String,
    pub description: String,
    pub user_stories: Vec<String>,
}

/// Full Product Requirements Document artifact.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrdArtifact {
    pub title: String,
    pub version: String,
    pub status: String,
    pub executive_summary: String,
    pub problem_statement: String,
    pub solution_overview: String,
    pub target_personas: Vec<Persona>,
    pub functional_requirements: Vec<FunctionalRequirement>,
    pub user_stories: Vec<UserStory>,
    pub non_functional_requirements: NonFunctionalRequirements,
    pub out_of_scope: Vec<String>,
    pub success_metrics: Vec<SuccessMetric>,
    pub risks: Vec<Risk>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Persona {
    pub name: String,
    pub role: String,
    pub pain_points: Vec<String>,
    pub goals: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NonFunctionalRequirements {
    pub performance: Vec<String>,
    pub security: Vec<String>,
    pub scalability: Vec<String>,
    pub availability: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SuccessMetric {
    pub metric: String,
    pub baseline: String,
    pub target: String,
    pub measurement_method: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Risk {
    pub description: String,
    pub probability: String,
    pub impact: String,
    pub mitigation: String,
}

pub fn brief_artifact_schema() -> Value {
    json!({
        "type": "object",
        "properties": {
            "title": { "type": "string" },
            "problem_statement": { "type": "string" },
            "target_audience": { "type": "string" },
            "goals": { "type": "array", "items": { "type": "string" } },
            "non_goals": { "type": "array", "items": { "type": "string" } },
            "constraints": { "type": "array", "items": { "type": "string" } },
            "success_metrics": { "type": "array", "items": { "type": "string" } },
            "timeline_weeks": { "type": "integer" }
        },
        "required": ["title", "problem_statement", "target_audience", "goals", "non_goals", "constraints", "success_metrics", "timeline_weeks"]
    })
}

pub fn prd_artifact_schema() -> Value {
    json!({
        "type": "object",
        "properties": {
            "title": { "type": "string" },
            "version": { "type": "string" },
            "status": { "type": "string" },
            "executive_summary": { "type": "string" },
            "problem_statement": { "type": "string" },
            "solution_overview": { "type": "string" },
            "target_personas": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": { "type": "string" },
                        "role": { "type": "string" },
                        "pain_points": { "type": "array", "items": { "type": "string" } },
                        "goals": { "type": "array", "items": { "type": "string" } }
                    },
                    "required": ["name", "role", "pain_points", "goals"]
                }
            },
            "functional_requirements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": { "type": "string" },
                        "section": { "type": "string" },
                        "description": { "type": "string" },
                        "user_stories": { "type": "array", "items": { "type": "string" } }
                    },
                    "required": ["id", "section", "description", "user_stories"]
                }
            },
            "user_stories": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": { "type": "string" },
                        "title": { "type": "string" },
                        "as_a": { "type": "string" },
                        "i_want": { "type": "string" },
                        "so_that": { "type": "string" },
                        "priority": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
                        "acceptance_criteria": { "type": "array", "items": { "type": "string" } },
                        "story_points": { "type": "integer" }
                    },
                    "required": ["id", "title", "as_a", "i_want", "so_that", "priority", "acceptance_criteria", "story_points"]
                }
            },
            "non_functional_requirements": {
                "type": "object",
                "properties": {
                    "performance": { "type": "array", "items": { "type": "string" } },
                    "security": { "type": "array", "items": { "type": "string" } },
                    "scalability": { "type": "array", "items": { "type": "string" } },
                    "availability": { "type": "string" }
                },
                "required": ["performance", "security", "scalability", "availability"]
            },
            "out_of_scope": { "type": "array", "items": { "type": "string" } },
            "success_metrics": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "metric": { "type": "string" },
                        "baseline": { "type": "string" },
                        "target": { "type": "string" },
                        "measurement_method": { "type": "string" }
                    },
                    "required": ["metric", "baseline", "target", "measurement_method"]
                }
            },
            "risks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "description": { "type": "string" },
                        "probability": { "type": "string", "enum": ["low", "medium", "high"] },
                        "impact": { "type": "string", "enum": ["low", "medium", "high"] },
                        "mitigation": { "type": "string" }
                    },
                    "required": ["description", "probability", "impact", "mitigation"]
                }
            }
        },
        "required": [
            "title", "version", "status", "executive_summary", "problem_statement",
            "solution_overview", "target_personas", "functional_requirements", "user_stories",
            "non_functional_requirements", "out_of_scope", "success_metrics", "risks"
        ]
    })
}
