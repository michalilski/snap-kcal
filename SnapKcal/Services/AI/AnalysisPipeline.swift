import Foundation

/// Runs one provider call with the plan's retry and fallback rules, remembering per-model incompatibilities.
@MainActor
struct AnalysisPipeline {
    let settings: AppSettings
    var retryDelay: (TimeInterval?) -> Duration = { .seconds($0 ?? 2) }

    func run(provider: any AIProvider, image: Data, context: AnalysisContext, model: AIModel, apiKey: String) async throws(AIError) -> AnalysisResult {
        var options = initialOptions(for: model)
        var retriedTransient = false
        var retriedDecoding = false
        while true {
            do {
                return try await provider.analyze(imageJPEG: image, context: context, model: model, apiKey: apiKey, options: options)
            } catch let error as AIError {
                switch error {
                case .badRequest(let message) where options.useEffort && mentions(message, ["reasoning", "effort"]):
                    options.useEffort = false
                    settings.modelsWithoutReasoning.insert(model.id)
                case .badRequest(let message) where options.useSchema && mentions(message, ["format", "schema", "output_config", "image"]):
                    options.useSchema = false
                    settings.modelsWithoutSchema.insert(model.id)
                case .rateLimited(let retryAfter) where !retriedTransient:
                    retriedTransient = true
                    try? await Task.sleep(for: retryDelay(retryAfter))
                case .overloaded where !retriedTransient:
                    retriedTransient = true
                    try? await Task.sleep(for: retryDelay(nil))
                case .decoding where !retriedDecoding:
                    retriedDecoding = true
                default:
                    throw error
                }
            } catch is CancellationError {
                throw .timeout
            } catch {
                throw .badRequest(error.localizedDescription)
            }
        }
    }

    func initialOptions(for model: AIModel) -> AnalysisOptions {
        let schemaAllowed = !settings.modelsWithoutSchema.contains(model.id)
        let effortAllowed = !settings.modelsWithoutReasoning.contains(model.id)
        switch model.provider {
        case .openai:
            return AnalysisOptions(useSchema: schemaAllowed, useEffort: effortAllowed && OpenAIRequests.isReasoningModel(model.id))
        case .anthropic:
            return AnalysisOptions(
                useSchema: schemaAllowed && model.supportsStructuredOutput == true,
                useEffort: effortAllowed && model.supportsEffort == true
            )
        }
    }

    private func mentions(_ message: String, _ words: [String]) -> Bool {
        let lowered = message.lowercased()
        return words.contains { lowered.contains($0) }
    }
}
