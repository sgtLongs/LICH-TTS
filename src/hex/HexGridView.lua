local HexGridView = {}

function HexGridView.buildRenderState(model, session)
    session = session or {}

    return {
        selectedCells = model.selectedCells,
        hoveredCells = session.hoveredCells or {},
        menuTargetCell = session.menuTargetCell,
        rotationCandidateCells = session.rotationCandidateCells or {}
    }
end

function HexGridView.draw(builder, board, cells, surfaceY, model, session)
    return builder.draw(
        board,
        cells,
        surfaceY,
        HexGridView.buildRenderState(model, session)
    )
end

return HexGridView
