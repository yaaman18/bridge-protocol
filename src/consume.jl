struct Consumer{F}
    fn::F
end

consume(consumer::Consumer, payload) = consumer.fn(payload)

function check_consumer_preserves_k3(
    consumer::Consumer,
    payload,
    alpha_rel,
    sigma_rel,
    all_M,
    all_E,
)
    consume(consumer, payload)
    check_galois_conn(alpha_rel, sigma_rel, all_M, powerset(all_E))
end
