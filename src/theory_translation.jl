struct FiniteTheory{S,FS,FM,F}
    signatures::Vector{S}
    sentences::FS
    models::FM
    satisfies::F
end

struct FiniteTheoryTranslation{A,B,FS,FQ,FR}
    source::A
    target::B
    signature_map::FS
    sentence_map::FQ
    reduct::FR
end

function check_satisfaction_preserving(translation::FiniteTheoryTranslation)
    source = translation.source
    target = translation.target
    all(source.signatures) do signature
        target_signature = translation.signature_map(signature)
        target_signature in target.signatures || return false
        all((model, sentence)
            for model in target.models(target_signature),
                sentence in source.sentences(signature)) do pair
            model, sentence = pair
            source.satisfies(translation.reduct(signature, model), sentence) ==
                target.satisfies(model, translation.sentence_map(signature, sentence))
        end
    end
end

function check_conservative_translation(translation::FiniteTheoryTranslation)
    check_satisfaction_preserving(translation) || return false
    source = translation.source
    target = translation.target
    all(source.signatures) do signature
        target_signature = translation.signature_map(signature)
        all(source.models(signature)) do source_model
            any(
                translation.reduct(signature, target_model) == source_model
                for target_model in target.models(target_signature)
            )
        end
    end
end

@enum TranslationResult begin
    translation_structural
    translation_functional
    translation_bridge
    translation_untranslated
end

@enum CoreGuarantee begin
    core_none
    core_model
    core_machine_checked
end

@enum AuditGuarantee begin
    audit_none
    audit_bounded_guarantee
    audit_simulation_sound
    audit_implementation_linked
end

@enum ViabilityGuarantee begin
    viability_none
    viability_recoverable
    viability_possible_live
    viability_fair_live
    viability_bounded_live
end

@enum GenerativeGuarantee begin
    generative_none
    generative_observed
    generative_fresh
    generative_cofinal
end

@enum TranslationGuarantee begin
    translation_none
    translation_glossary
    translation_satisfaction_preserving
    translation_conservative
end

struct GuaranteeProfile
    core::CoreGuarantee
    audit::AuditGuarantee
    viability::ViabilityGuarantee
    generative::GenerativeGuarantee
    translation::TranslationGuarantee
    phenomenal_claim::Symbol

    function GuaranteeProfile(
        core::CoreGuarantee,
        audit::AuditGuarantee,
        viability::ViabilityGuarantee,
        generative::GenerativeGuarantee,
        translation::TranslationGuarantee;
        phenomenal_claim::Symbol=:not_certified,
    )
        phenomenal_claim == :not_certified ||
            throw(ArgumentError("phenomenal_claim must remain :not_certified"))
        new(core, audit, viability, generative, translation, phenomenal_claim)
    end
end
