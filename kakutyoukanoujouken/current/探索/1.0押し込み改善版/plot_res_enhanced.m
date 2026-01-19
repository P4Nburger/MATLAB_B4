function [top_designs, fig_handle] = plot_res_enhanced(res, out_dir)
    z_min_required = 0.5;  % [mm] 最低限の初期たわみ
    cv = [res.converged]; r = res(cv);
    if isempty(r), fprintf('No converged results\n'); top_designs = []; fig_handle = []; return; end
    
    % データ点を1000点に制限（高速化・タイムアウト回避）
    n_all = length(r);
    if n_all > 1000
        idx_sample = randperm(n_all, 1000);
        r_plot = r(idx_sample);
        fprintf('Plotting %d / %d points (random sampling for speed)\n', 1000, n_all);
    else
        r_plot = r;
    end
    
    % プロット用データ（サンプリング済み）
    za = [r_plot.z_eq_mm]; 
    aa = [r_plot.A_z_mm]; 
    fa = [r_plot.f_res_Hz]; 
    xp = [r_plot.x_push_m]*1000; 
    ws = [r_plot.w1_stiff_m]*1000;
    wm = [r_plot.w1_mass_m]*1000; 
    Ls = [r_plot.L_m]*1000;
    ratio_all = aa ./ za;
    
    % ========== 修正：ratio で降順ソート（全データから） ==========
    za_all = [r.z_eq_mm]; 
    aa_all = [r.A_z_mm];
    ratio_all_full = aa_all ./ za_all;
    [~, ix] = sort(ratio_all_full, 'descend');  % A_z/z_eq 比で降順
    % ============================================================
    
    top_designs = r(ix(1:min(20, length(r))));
    ratio_top = [top_designs.A_z_mm] ./ [top_designs.z_eq_mm];
    
    % 統計情報
    n_snap = sum(ratio_all_full > 1.0);
    n_total = length(ratio_all_full);
    
    % ========== 8グラフのプロット ==========
    fig_handle = figure('Color','w','Position',[50 50 1800 1000]);
    
    % (1) Top 20: A_z/z_eq ratio（ratio順にソート済み）
    subplot(2,4,1);
    bar(ratio_top); hold on;
    yline(1.0, 'r--', 'LineWidth', 2);
    xlabel('Rank'); ylabel('A_z / z_{eq}');
    title('Top 20 by A_z/z_{eq} ratio'); 
    legend('Ratio', 'Threshold=1.0', 'Location','northeast');
    grid on;
    
    % (2) Distribution of A_z/z_eq ratio
    subplot(2,4,2);
    histogram(ratio_all, 40); hold on;
    xline(1.0, 'r--', 'LineWidth', 2);
    xlabel('A_z / z_{eq}'); ylabel('Count');
    title('Distribution (snapthrough if >1.0)');
    text(1.5, max(ylim)*0.8, sprintf('%.1f%% > 1.0', 100*n_snap/n_total), ...
        'FontSize', 10, 'FontWeight', 'bold');
    grid on;
    
    % (3) Design space map
    subplot(2,4,3);
    scatter(xp, za, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.7);
    colorbar; caxis([0 2]); colormap(gca, jet);
    hold on; 
    x_theory = linspace(0, 1, 100);
    z_theory = sqrt(2*x_theory/0.2794);
    plot(x_theory, z_theory, 'k--', 'LineWidth', 1.5);
    xlabel('x_{push} [mm]'); ylabel('z_{eq} [mm]');
    title('Design Space (color=A_z/z_{eq})');
    legend('Data', 'Theory z_{eq}', 'Location','northwest');
    grid on;
    
    % (4) x_push vs A_z
    subplot(2,4,4);
    scatter(xp, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('x_{push} [mm]'); ylabel('A_z [mm]');
    title('x_{push} effect (color=ratio)');
    grid on;
    
    % (5) w1_stiff vs A_z (log scale)
    subplot(2,4,5);
    scatter(ws, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    set(gca, 'XScale', 'log');
    colorbar; caxis([0 2]);
    xlabel('w1_{stiff} [mm]'); ylabel('A_z [mm]');
    title('w1_{stiff} effect (log scale)');
    grid on;
    
    % (6) w1_mass vs A_z
    subplot(2,4,6);
    scatter(wm, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('w1_{mass} [mm]'); ylabel('A_z [mm]');
    title('w1_{mass} effect');
    grid on;
    
    % (7) L vs A_z
    subplot(2,4,7);
    scatter(Ls, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('L [mm]'); ylabel('A_z [mm]');
    title('L (span) effect');
    grid on;
    
    % (8) f_res vs A_z
    subplot(2,4,8);
    scatter(fa, aa, 30, ratio_all, 'filled', 'MarkerFaceAlpha', 0.6);
    colorbar; caxis([0 2]);
    xlabel('f_{res} [Hz]'); ylabel('A_z [mm]');
    title('Resonance frequency effect');
    grid on;
    
    % ========== 安全な保存方法 ==========
    fig_file = fullfile(out_dir, 'results_summary_enhanced.png');
    try
        exportgraphics(fig_handle, fig_file, 'Resolution', 300);
        fprintf('[SAVED] Enhanced figure: %s\n', fig_file);
    catch ME
        fprintf('[WARNING] exportgraphics failed: %s\n', ME.message);
        try
            print(fig_handle, fig_file, '-dpng', '-r300');
            fprintf('[SAVED] Enhanced figure (print): %s\n', fig_file);
        catch ME2
            fprintf('[ERROR] Could not save figure. Save manually.\n');
        end
    end
    
    % ========== コンソール出力（ratio順） ==========
    fprintf('\n========== TOP 20 (Sorted by A_z/z_eq ratio) ==========\n');
    fprintf('Rank | x_push | w_stiff | w_mass | L    | A_z    | z_eq   | f_res | Az/zeq\n');
    fprintf('-----|--------|---------|--------|------|--------|--------|-------|-------\n');
    for i = 1:min(20, length(top_designs))
        fprintf('%4d | %6.3f | %7.2f | %6.1f | %4.1f | %6.3f | %6.3f | %6.1f | %.3f\n', ...
            i, top_designs(i).x_push_m*1000, top_designs(i).w1_stiff_m*1000, ...
            top_designs(i).w1_mass_m*1000, top_designs(i).L_m*1000, ...
            top_designs(i).A_z_mm, top_designs(i).z_eq_mm, ...
            top_designs(i).f_res_Hz, ratio_top(i));
    end
    fprintf('=======================================================\n\n');
    
    % ========== Best design summary ==========
    best = top_designs(1);
    fprintf('BEST DESIGN (Rank 1 - Highest A_z/z_eq ratio):\n');
    fprintf('  x_push   = %.3f mm\n', best.x_push_m*1000);
    fprintf('  w1_stiff = %.2f mm\n', best.w1_stiff_m*1000);
    fprintf('  w1_mass  = %.1f mm\n', best.w1_mass_m*1000);
    fprintf('  L        = %.1f mm\n', best.L_m*1000);
    fprintf('  A_z      = %.3f mm\n', best.A_z_mm);
    fprintf('  z_eq     = %.3f mm\n', best.z_eq_mm);
    fprintf('  f_res    = %.1f Hz\n', best.f_res_Hz);
    fprintf('  A_z/z_eq = %.3f  <-- MAXIMUM RATIO\n\n', ratio_top(1));
    
    if ratio_top(1) > 1.5
        fprintf('>>> VERY HIGH snapthrough potential (A_z/z_eq > 1.5)\n\n');
    elseif ratio_top(1) > 1.0
        fprintf('>>> HIGH snapthrough potential (A_z/z_eq > 1.0)\n\n');
    elseif ratio_top(1) > 0.5
        fprintf('>>> MODERATE snapthrough potential (0.5 < A_z/z_eq < 1.0)\n\n');
    else
        fprintf('>>> LOW snapthrough potential (A_z/z_eq < 0.5)\n\n');
    end
    
    fprintf('Statistics:\n');
    fprintf('  Designs with A_z/z_eq > 1.0: %d / %d (%.1f%%)\n', ...
        n_snap, n_total, 100*n_snap/n_total);
    fprintf('  Max A_z/z_eq ratio: %.3f (Rank 1)\n', max(ratio_all_full));
    fprintf('  Mean A_z/z_eq ratio: %.3f\n\n', mean(ratio_all_full));
end
