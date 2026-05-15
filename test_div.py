def test_div():
    A = 0x1_AABB_CCDD_EEFF
    B = 0x1_1122_3344_5566
    
    # Python equivalent of our Sequential Divider algorithm
    m_a = A
    m_b = B
    
    D = m_b
    PR = m_a
    Q = 0
    
    for i in range(57):
        if PR >= D:
            PR = (PR - D) << 1
            Q = (Q << 1) | 1
        else:
            PR = PR << 1
            Q = (Q << 1) | 0
            
    print(f"Sequential Q: {hex(Q)}")

    # Combinatorial equivalent
    comb_Q = (m_a << 56) // m_b
    print(f"Combinatorial Q: {hex(comb_Q)}")

    # Is PR doing shift-then-subtract correctly?
    PR2 = m_a
    Q2 = 0
    for i in range(57):
        PR2_shifted = PR2 << 1
        if PR2_shifted >= D:
            PR2 = PR2_shifted - D
            Q2 = (Q2 << 1) | 1
        else:
            PR2 = PR2_shifted
            Q2 = (Q2 << 1) | 0
    print(f"Shift-Before-Compare Q: {hex(Q2)}")

test_div()
