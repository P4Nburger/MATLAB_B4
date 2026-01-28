function snap_summary = verify_snapthrough_top20(top_designs, fx, cfg, out_dir)
    % ディレクトリ処理
    if ~isAbsolutePath(out_dir)
        out_dir = fullfile(pwd, out_dir);
    end
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    n_designs = length(top_designs);
    snap_results = struct('rank', {}, 'ratio', {}, 'snapped', {}, ...
                          'z_max', {}, 'z_min', {}, 'zero_crosses', {});
    
    fprintf('\n========================================\n');
    fprintf('   Top 20 Snapthrough Verification\n');
    fprintf('========================================\n');
    fprintf('Testing %d designs...\n\n', n_designs);
    
    for i = 1:n_designs
        d = top_designs(i);
        ratio = d.A_z_mm / d.z_eq_mm;
        
        fprintf('--- Rank %d/%d (ratio=%.3f) ---\n', i, n_designs, ratio);
        fprintf('  xp=%.3f ws=%.2f wm=%.1f L=%.1f\n', ...
            d.x_push_m*1000, d.w1_stiff_m*1000, d.w1_mass_m*1000, d.L_m*1000);
        
        % パラメータ構築
        z_mm = d.z_eq_mm; z = z_mm / 1000;
        p.L = d.L_m; p.w1_stiff = d.w1_stiff_m; p.w1_mass = d.w1_mass_m;
        p.t1 = fx.t1_m; p.E1 = fx.E1_Pa; p.rho1 = fx.rho1;
        p.delta = fx.delta; p.P0 = fx.P0_Pa;
        p.m1 = p.rho1 * p.L * p.w1_mass * p.t1;
        p.I1 = p.w1_stiff * p.t1^3 / 12;
        p.k1 = 384 * p.E1 * p.I1 / (p.L^3);
        p.Kc = p.E1 * (p.w1_stiff * p.t1) / p.L;
        p.c1 = 2 * p.delta * sqrt(p.m1 * p.k1);
        p.S2 = fx.S2_m2; p.rho2 = fx.rho2; p.k2 = fx.k2_base_Npm;
        p.m2 = p.rho2 * p.S2 * p.L;
        p.c2 = 2 * p.delta * sqrt(p.m2 * p.k2);
        p.Gm = (fx.C_eff / 2) * 1000;
        ceq = p.k1 / (2 * p.Gm * p.Kc);
        yeq = p.Gm * z^2 + ceq;
        ynat = yeq + (p.Kc * ceq) / p.k2;
        p.z_eq = z; p.y_eq = yeq; p.y_nat = ynat; p.freq = d.f_res_Hz;
        
        x0 = [z; yeq; 0; 0];
        
        % 時刻歴計算
        t_on = 0.5;
        [t, x] = ode45(@(t,x) eom(t,x,p,t_on), [0 5], x0, cfg.ode_opt);
        
        z_disp = x(:,1);
        z_max = max(z_disp)*1000;
        z_min = min(z_disp)*1000;
        
        % ========== 改善版：ゼロクロスカウント（正しい実装） ==========
        threshold = 0.05 * abs(z);  % [m]
        
        % 方法1：シンプルで確実な判定（領域カウント）
        % 正領域と負領域を交互に訪れた回数をカウント
        in_positive = z_disp > threshold;
        in_negative = z_disp < -threshold;
        
        % 正領域に入った回数と負領域に入った回数の最小値が往復回数
        % 連続する同じ領域は1回とカウント
        pos_entries = 0;
        neg_entries = 0;
        currently_in_pos = false;
        currently_in_neg = false;
        
        for j = 1:length(z_disp)
            if in_positive(j)
                if ~currently_in_pos
                    pos_entries = pos_entries + 1;
                    currently_in_pos = true;
                    currently_in_neg = false;
                end
            elseif in_negative(j)
                if ~currently_in_neg
                    neg_entries = neg_entries + 1;
                    currently_in_neg = true;
                    currently_in_pos = false;
                end
            else
                % 中立領域（-threshold < z < threshold）
                % 状態を保持（フラグをリセットしない）
            end
        end
        
        % スナップスルー回数：正と負を交互に訪れた回数
        % 例：pos→neg→pos なら 2回クロス
        n_crosses = min(pos_entries, neg_entries) + abs(pos_entries - neg_entries) - 1;
        if n_crosses < 0
            n_crosses = 0;
        end
        
        % もっと簡単な方法：min(pos_entries, neg_entries) でもOK
        % （片方が多い場合、往復は少ない方で制限される）
        n_crosses_simple = pos_entries + neg_entries - 1;  % 領域変化回数
        if pos_entries > 0 && neg_entries > 0
            n_crosses = n_crosses_simple;
        else
            n_crosses = 0;
        end
        
        % ゼロを跨いだかどうか
        crosses_zero = (pos_entries > 0) && (neg_entries > 0);
        snapped = crosses_zero;
        % ==============================================
        
        % 結果保存
        snap_results(i).rank = i;
        snap_results(i).ratio = ratio;
        snap_results(i).snapped = snapped;
        snap_results(i).z_max = z_max;
        snap_results(i).z_min = z_min;
        snap_results(i).zero_crosses = n_crosses;
        
        if snapped
            fprintf('  >> SNAPTHROUGH (pos=%d, neg=%d, crosses=%d)\n', ...
                pos_entries, neg_entries, n_crosses);
        else
            fprintf('  >> No snapthrough\n');
        end
        fprintf('  z: %.3f ~ %.3f mm (z_eq=%.3f mm)\n\n', ...
            z_min, z_max, z_mm);
        
        % 図を保存（簡略版）
        fig = figure('Visible','off','Position',[100 100 1200 400]);
        
        subplot(1,3,1);
        plot(t, z_disp*1000, 'b', 'LineWidth', 1.5); hold on;
        xline(t_on, 'k--', 'LineWidth', 1.5);
        yline(0, 'r--', 'LineWidth', 1.5);
        yline(threshold*1000, 'g:', 'LineWidth', 1);
        yline(-threshold*1000, 'g:', 'LineWidth', 1);
        xlabel('Time [s]'); ylabel('z [mm]');
        title(sprintf('Rank %d: ratio=%.2f', i, ratio));
        grid on; xlim([0 5]);
        
        subplot(1,3,2);
        plot(t, (x(:,2)-yeq)*1000, 'r', 'LineWidth', 1.5);
        xlabel('Time [s]'); ylabel('Frame Δy [mm]');
        title('Frame expansion');
        grid on; xlim([0 5]);
        
        subplot(1,3,3);
        plot(z_disp*1000, x(:,3)*1000, 'b', 'LineWidth', 1); hold on;
        plot(z_disp(1)*1000, x(1,3)*1000, 'go', 'MarkerSize', 8, 'LineWidth', 2);
        xline(0, 'r--', 'LineWidth', 1);
        xlabel('z [mm]'); ylabel('dz/dt [mm/s]');
        title(sprintf('Phase (crosses=%d)', n_crosses));
        grid on;
        
        png_file = fullfile(out_dir, sprintf('snap_rank%02d.png', i));
        try
            print(fig, png_file, '-dpng', '-r100');
        catch
        end
        close(fig);
    end
    
    % 統計
    ratios = [snap_results.ratio];
    snapped_flags = [snap_results.snapped];
    n_snapped = sum(snapped_flags);
    
    fprintf('========================================\n');
    fprintf('   SUMMARY\n');
    fprintf('========================================\n');
    fprintf('Snapthrough confirmed: %d/%d (%.1f%%)\n', n_snapped, n_designs, 100*n_snapped/n_designs);
    fprintf('\n--- Detailed Results ---\n');
    fprintf('Rank | Ratio | Snapped | Crosses | z_min   | z_max\n');
    fprintf('-----|-------|---------|---------|---------|--------\n');
    for i = 1:n_designs
        fprintf('%4d | %5.2f | %7s | %7d | %7.3f | %7.3f\n', ...
            snap_results(i).rank, snap_results(i).ratio, ...
            mat2str(snap_results(i).snapped), snap_results(i).zero_crosses, ...
            snap_results(i).z_min, snap_results(i).z_max);
    end
    
    % サマリープロット
    fig_summary = figure('Color','w','Position',[100 100 1200 500]);
    
    subplot(1,2,1);
    bar(ratios); hold on;
    yline(1.0, 'r--', 'LineWidth', 2);
    for i = 1:n_designs
        if snap_results(i).snapped
            plot(i, ratios(i), 'go', 'MarkerSize', 10, 'LineWidth', 2);
        else
            plot(i, ratios(i), 'rx', 'MarkerSize', 10, 'LineWidth', 2);
        end
    end
    xlabel('Rank'); ylabel('A_z / z_{eq}');
    title('Snapthrough verification');
    grid on;
    
    subplot(1,2,2);
    scatter(ratios, [snap_results.zero_crosses], 100, snapped_flags, 'filled'); hold on;
    xline(1.0, 'r--', 'LineWidth', 2);
    xlabel('A_z / z_{eq} ratio'); ylabel('Zero crossing count');
    title('Ratio vs Snapthrough frequency');
    colorbar('Ticks', [0 1], 'TickLabels', {'No snap', 'Snapped'});
    grid on;
    
    summary_file = fullfile(out_dir, 'snapthrough_summary.png');
    try
        print(fig_summary, summary_file, '-dpng', '-r150');
    catch
    end
    close(fig_summary);
    
    snap_summary.results = snap_results;
    snap_summary.n_total = n_designs;
    snap_summary.n_snapped = n_snapped;
    snap_summary.success_rate = n_snapped / n_designs;
end

function dx = eom(t, x, p, t0)
    z = x(1); y = x(2); dz = x(3); dy = x(4);
    ct = y - (p.Gm * z^2);
    Fz = p.k1 * z - p.Kc * ct * (2 * p.Gm * z);
    Fy = p.k2 * (y - p.y_nat) + p.Kc * ct;
    if t >= t0
        rp = min(1.0, (t - t0) / 0.1);
        Fs = rp * p.P0 * (p.L * p.w1_mass) * cos(2*pi*p.freq*t);
    else
        Fs = 0;
    end
    ddz = (Fs - p.c1*dz - Fz) / p.m1;
    ddy = (0  - p.c2*dy - Fy) / p.m2;
    dx = [dz; dy; ddz; ddy];
end

function result = isAbsolutePath(pathStr)
    result = ~isempty(regexp(pathStr, '^([A-Za-z]:[\\/]|/)', 'once'));
end
